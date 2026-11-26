namespace Zamara.Pension;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Posting;
using Microsoft.Sales.Customer;

/// <summary>
/// Posts one chunk of validated queue lines in a single transaction:
///  - two member ledger entries per line (employee and employer share);
///  - one employer invoice per batch for the total of the posted lines
///    (Dr Customer -> Contribution Receivable, Cr Member Liability) through Gen. Jnl.-Post Line;
///  - a late remittance penalty invoice, once per batch.
/// The processor runs this codeunit with Codeunit.Run, so any error rolls the whole chunk back.
/// </summary>
codeunit 50103 "PEN Contribution Post"
{
    TableNo = "PEN Contribution Queue";

    trigger OnRun()
    begin
        PostLines(Rec);
    end;

    var
        PensionSetup: Record "PEN Pension Setup";
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        PensionMgt: Codeunit "PEN Pension Mgt";
        BatchTotals: Dictionary of [Code[20], Decimal];
        PostedCount: Integer;
        FailedCount: Integer;
        DeadLetterCount: Integer;
        SkippedCount: Integer;
        AlreadyPostedErr: Label 'Member ledger entries already exist for member %1 and period %2.', Comment = '%1 = member, %2 = period';
        InvoiceDescriptionTxt: Label 'Pension contributions %1 %2', Comment = '%1 = employer no., %2 = period';
        PenaltyDescriptionTxt: Label 'Late remittance penalty %1 %2', Comment = '%1 = employer no., %2 = period';

    procedure GetPostedCount(): Integer
    begin
        exit(PostedCount);
    end;

    procedure GetFailedCount(): Integer
    begin
        exit(FailedCount);
    end;

    procedure GetDeadLetterCount(): Integer
    begin
        exit(DeadLetterCount);
    end;

    procedure GetSkippedCount(): Integer
    begin
        exit(SkippedCount);
    end;

    local procedure PostLines(var TempValidLine: Record "PEN Contribution Queue")
    var
        BatchNo: Code[20];
        PostedAt: DateTime;
    begin
        PensionSetup.GetSetup();
        PostedAt := CurrentDateTime();
        Clear(BatchTotals);

        TempValidLine.Reset();
        if TempValidLine.FindSet() then
            repeat
                PostLine(TempValidLine, PostedAt);
            until TempValidLine.Next() = 0;

        foreach BatchNo in BatchTotals.Keys() do begin
            PostContributionInvoice(BatchNo, BatchTotals.Get(BatchNo));
            PostPenaltyIfLate(BatchNo);
        end;
    end;

    local procedure PostLine(TempValidLine: Record "PEN Contribution Queue"; PostedAt: DateTime)
    var
        QueueLine: Record "PEN Contribution Queue";
        PostingDate: Date;
    begin
        QueueLine.ReadIsolation := IsolationLevel::UpdLock;
        if not QueueLine.Get(TempValidLine."Batch No.", TempValidLine."Line No.") then
            exit;
        // Another session may have taken the line over (for example after a stale-claim reset). Leave it alone.
        if not PensionMgt.IsClaimedByThisSession(QueueLine) then begin
            SkippedCount += 1;
            exit;
        end;
        // Last line of defence against double posting: check the member ledger itself, under lock.
        if MemberLedgerEntryExists(QueueLine."Member No.", QueueLine.Period) then begin
            if PensionMgt.MarkLineFailed(QueueLine, StrSubstNo(AlreadyPostedErr, QueueLine."Member No.", QueueLine.Period), PensionSetup."Max Retry Attempts") then
                DeadLetterCount += 1
            else
                FailedCount += 1;
            exit;
        end;

        PostingDate := PensionMgt.GetPeriodEndDate(QueueLine.Period);
        QueueLine."Scheme Code" := TempValidLine."Scheme Code";
        InsertMemberLedgerEntry(QueueLine, "PEN Ledger Entry Type"::"Employee Contribution", QueueLine."Employee Amount", PostingDate, PostedAt);
        InsertMemberLedgerEntry(QueueLine, "PEN Ledger Entry Type"::"Employer Contribution", QueueLine."Employer Amount", PostingDate, PostedAt);

        QueueLine.Status := QueueLine.Status::Posted;
        QueueLine."Posted Document No." := QueueLine."Batch No.";
        QueueLine."Posted At" := PostedAt;
        QueueLine."Last Attempt At" := PostedAt;
        QueueLine."Last Error" := '';
        QueueLine.Modify();

        AddToBatchTotal(QueueLine."Batch No.", QueueLine."Line Amount");
        PostedCount += 1;
        OnAfterPostQueueLine(QueueLine);
    end;

    local procedure InsertMemberLedgerEntry(QueueLine: Record "PEN Contribution Queue"; EntryType: Enum "PEN Ledger Entry Type"; EntryAmount: Decimal; PostingDate: Date; PostedAt: DateTime)
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
    begin
        MemberLedgerEntry.Init();
        MemberLedgerEntry."Entry No." := 0; // AutoIncrement assigns it.
        MemberLedgerEntry."Member No." := QueueLine."Member No.";
        MemberLedgerEntry."Employer No." := QueueLine."Employer No.";
        MemberLedgerEntry."Scheme Code" := QueueLine."Scheme Code";
        MemberLedgerEntry."Posting Date" := PostingDate;
        MemberLedgerEntry.Period := QueueLine.Period;
        MemberLedgerEntry."Entry Type" := EntryType;
        MemberLedgerEntry.Amount := EntryAmount;
        MemberLedgerEntry."Batch No." := QueueLine."Batch No.";
        MemberLedgerEntry."Batch Line No." := QueueLine."Line No.";
        MemberLedgerEntry."Document No." := QueueLine."Batch No.";
        MemberLedgerEntry."Posted By" := CopyStr(UserId(), 1, MaxStrLen(MemberLedgerEntry."Posted By"));
        MemberLedgerEntry."Posted At" := PostedAt;
        MemberLedgerEntry.Insert();
    end;

    local procedure MemberLedgerEntryExists(MemberNo: Code[20]; Period: Code[7]): Boolean
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
    begin
        MemberLedgerEntry.SetCurrentKey("Member No.", Period, "Entry Type");
        MemberLedgerEntry.SetRange("Member No.", MemberNo);
        MemberLedgerEntry.SetRange(Period, Period);
        exit(not MemberLedgerEntry.IsEmpty());
    end;

    local procedure AddToBatchTotal(BatchNo: Code[20]; LineAmount: Decimal)
    begin
        if BatchTotals.ContainsKey(BatchNo) then
            BatchTotals.Set(BatchNo, BatchTotals.Get(BatchNo) + LineAmount)
        else
            BatchTotals.Add(BatchNo, LineAmount);
    end;

    /// <summary>
    /// One summarised invoice per batch for this run: Dr Employer (customer), Cr Member Liability.
    /// The customer posting group sends the debit to the scheme's Contribution Receivable account.
    /// </summary>
    local procedure PostContributionInvoice(BatchNo: Code[20]; InvoiceAmount: Decimal)
    var
        Batch: Record "PEN Contribution Batch";
        Employer: Record Customer;
        Scheme: Record "PEN Scheme";
        GenJournalLine: Record "Gen. Journal Line";
        AllowBatchInvoiceNo: Codeunit "PEN Allow Batch Invoice No.";
    begin
        if InvoiceAmount = 0 then
            exit;
        Batch.ReadIsolation := IsolationLevel::UpdLock;
        Batch.Get(BatchNo);
        GetEmployerAndScheme(Batch, Employer, Scheme);

        InitEmployerJournalLine(GenJournalLine, Batch, PensionMgt.GetPeriodEndDate(Batch.Period), Batch."No.");
        GenJournalLine."Bal. Account Type" := GenJournalLine."Bal. Account Type"::"G/L Account";
        GenJournalLine.Validate("Bal. Account No.", Scheme."Member Liability Acc.");
        GenJournalLine.Validate(Amount, InvoiceAmount);
        GenJournalLine.Description := CopyStr(StrSubstNo(InvoiceDescriptionTxt, Batch."Employer No.", Batch.Period), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine."Due Date" := Batch."Due Date";

        OnBeforePostContributionInvoice(GenJournalLine, Batch);

        // A later run (retry, or a batch split across chunks) invoices the same batch again under the same
        // Document No., which standard posting would reject as "Sales Invoice ... already exists".
        AllowBatchInvoiceNo.SetBatchNo(Batch."No.");
        BindSubscription(AllowBatchInvoiceNo);
        GenJnlPostLine.RunWithCheck(GenJournalLine);
        UnbindSubscription(AllowBatchInvoiceNo);
    end;

    /// <summary>
    /// If the batch arrived after the remittance due date, invoice the employer the late penalty
    /// (Dr Employer, Cr Penalty Income). "Penalty Posted" is set in the same transaction, so this
    /// happens once per batch however many times the batch is processed.
    /// </summary>
    local procedure PostPenaltyIfLate(BatchNo: Code[20])
    var
        Batch: Record "PEN Contribution Batch";
        Employer: Record Customer;
        Scheme: Record "PEN Scheme";
        GenJournalLine: Record "Gen. Journal Line";
        PenaltyAmount: Decimal;
    begin
        Batch.ReadIsolation := IsolationLevel::UpdLock;
        Batch.Get(BatchNo);
        if Batch."Penalty Posted" then
            exit;
        if not PensionMgt.IsBatchLate(Batch) then
            exit;
        PenaltyAmount := PensionMgt.CalcPenaltyAmount(Batch, PensionSetup);
        if PenaltyAmount <= 0 then
            exit;
        GetEmployerAndScheme(Batch, Employer, Scheme);

        InitEmployerJournalLine(GenJournalLine, Batch, Batch."Received Date", Batch.GetPenaltyDocumentNo());
        GenJournalLine."Bal. Account Type" := GenJournalLine."Bal. Account Type"::"G/L Account";
        GenJournalLine.Validate("Bal. Account No.", Scheme."Penalty Income Acc.");
        GenJournalLine.Validate(Amount, PenaltyAmount);
        GenJournalLine.Description := CopyStr(StrSubstNo(PenaltyDescriptionTxt, Batch."Employer No.", Batch.Period), 1, MaxStrLen(GenJournalLine.Description));
        GenJournalLine."Due Date" := Batch."Received Date";

        OnBeforePostPenaltyInvoice(GenJournalLine, Batch);
        GenJnlPostLine.RunWithCheck(GenJournalLine);

        Batch."Penalty Posted" := true;
        Batch."Penalty Amount" := PenaltyAmount;
        Batch.Modify();
    end;

    local procedure InitEmployerJournalLine(var GenJournalLine: Record "Gen. Journal Line"; Batch: Record "PEN Contribution Batch"; PostingDate: Date; DocumentNo: Code[20])
    begin
        GenJournalLine.Init();
        GenJournalLine."Posting Date" := PostingDate;
        GenJournalLine."Document Date" := Batch."Received Date";
        GenJournalLine."Document Type" := GenJournalLine."Document Type"::Invoice;
        GenJournalLine."Document No." := DocumentNo;
        GenJournalLine."External Document No." := CopyStr(Batch."Message ID", 1, MaxStrLen(GenJournalLine."External Document No."));
        GenJournalLine."Account Type" := GenJournalLine."Account Type"::Customer;
        GenJournalLine.Validate("Account No.", Batch."Employer No.");
        GenJournalLine."System-Created Entry" := true;
    end;

    local procedure GetEmployerAndScheme(Batch: Record "PEN Contribution Batch"; var Employer: Record Customer; var Scheme: Record "PEN Scheme")
    begin
        Employer.Get(Batch."Employer No.");
        Employer.TestField("PEN Scheme Code");
        Scheme.Get(Employer."PEN Scheme Code");
        Scheme.CheckPostingSetup();
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPostQueueLine(var QueueLine: Record "PEN Contribution Queue")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostContributionInvoice(var GenJournalLine: Record "Gen. Journal Line"; Batch: Record "PEN Contribution Batch")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostPenaltyInvoice(var GenJournalLine: Record "Gen. Journal Line"; Batch: Record "PEN Contribution Batch")
    begin
    end;
}
