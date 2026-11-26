namespace Zamara.Pension;

using Microsoft.Bank.BankAccount;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Posting;
using Microsoft.Foundation.NoSeries;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;

/// <summary>
/// Posts an employer receipt (the cash leg) in one transaction:
///  1. Marks the employer's open invoices for each batch on the lines with Applies-to ID and
///     Amount to Apply, oldest first (the contribution invoice, then the penalty).
///  2. Posts one payment through Gen. Jnl.-Post Line: Dr Bank, Cr Employer. The payment
///     applies to the marked invoices; any amount not allocated to a batch stays open on account.
///  3. Moves the receipt to the posted receipt tables.
/// </summary>
codeunit 50107 "PEN Receipt-Post"
{
    TableNo = "PEN Receipt Header";

    trigger OnRun()
    begin
        PostReceipt(Rec);
    end;

    var
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        PostedReceiptNo: Code[20];
        AmountMismatchErr: Label 'The receipt amount %1 does not equal the total of the lines %2.', Comment = '%1 = header amount, %2 = lines total';
        NoLinesErr: Label 'Receipt %1 has no lines. Use Suggest Lines, or add a line with no batch for a payment on account.', Comment = '%1 = receipt no.';
        LineAmountErr: Label 'Line %1 must have an amount greater than zero.', Comment = '%1 = line no.';
        WrongEmployerErr: Label 'Batch %1 belongs to employer %2, not %3.', Comment = '%1 = batch, %2 = batch employer, %3 = receipt employer';
        OverOutstandingErr: Label 'Line %1 allocates %2 to batch %3, but only %4 is outstanding.', Comment = '%1 = line, %2 = amount, %3 = batch, %4 = outstanding';
        PaymentDescriptionTxt: Label 'Pension receipt %1', Comment = '%1 = employer no.';

    procedure GetPostedReceiptNo(): Code[20]
    begin
        exit(PostedReceiptNo);
    end;

    local procedure PostReceipt(var ReceiptHeader: Record "PEN Receipt Header")
    var
        PostedReceiptHeader: Record "PEN Posted Receipt Header";
        AppliedAmount: Decimal;
    begin
        CheckReceipt(ReceiptHeader);
        PostedReceiptNo := GetPostedReceiptNumber(ReceiptHeader);
        AppliedAmount := MarkInvoicesForApplication(ReceiptHeader);
        PostPayment(ReceiptHeader, AppliedAmount);
        CreatePostedReceipt(ReceiptHeader, AppliedAmount, PostedReceiptHeader);
        ReceiptHeader.Delete(true);
        OnAfterPostReceipt(PostedReceiptHeader);
    end;

    local procedure CheckReceipt(var ReceiptHeader: Record "PEN Receipt Header")
    var
        Employer: Record Customer;
        BankAccount: Record "Bank Account";
        ReceiptLine: Record "PEN Receipt Line";
        Batch: Record "PEN Contribution Batch";
        Outstanding: Decimal;
    begin
        ReceiptHeader.TestField("Employer No.");
        ReceiptHeader.TestField("Receipt Date");
        ReceiptHeader.TestField("Bank Account No.");
        ReceiptHeader.TestField(Amount);

        Employer.Get(ReceiptHeader."Employer No.");
        Employer.TestField("PEN Pension Employer", true);
        BankAccount.Get(ReceiptHeader."Bank Account No.");
        BankAccount.TestField(Blocked, false);

        ReceiptLine.SetRange("Receipt No.", ReceiptHeader."No.");
        if ReceiptLine.IsEmpty() then
            Error(NoLinesErr, ReceiptHeader."No.");
        ReceiptHeader.CalcFields("Lines Total");
        if ReceiptHeader.Amount <> ReceiptHeader."Lines Total" then
            Error(AmountMismatchErr, ReceiptHeader.Amount, ReceiptHeader."Lines Total");

        ReceiptLine.FindSet();
        repeat
            if ReceiptLine.Amount <= 0 then
                Error(LineAmountErr, ReceiptLine."Line No.");
            if ReceiptLine."Batch No." <> '' then begin
                Batch.Get(ReceiptLine."Batch No.");
                if Batch."Employer No." <> ReceiptHeader."Employer No." then
                    Error(WrongEmployerErr, Batch."No.", Batch."Employer No.", ReceiptHeader."Employer No.");
                Outstanding := Batch.GetOutstandingAmount();
                if ReceiptLine.Amount > Outstanding then
                    Error(OverOutstandingErr, ReceiptLine."Line No.", ReceiptLine.Amount, Batch."No.", Outstanding);
            end;
        until ReceiptLine.Next() = 0;
    end;

    local procedure GetPostedReceiptNumber(ReceiptHeader: Record "PEN Receipt Header"): Code[20]
    var
        PensionSetup: Record "PEN Pension Setup";
        NoSeries: Codeunit "No. Series";
    begin
        PensionSetup.GetSetup();
        if PensionSetup."Posted Receipt Nos." = '' then
            exit(ReceiptHeader."No.");
        exit(NoSeries.GetNextNo(PensionSetup."Posted Receipt Nos.", ReceiptHeader."Receipt Date"));
    end;

    /// <summary>
    /// Sets Applies-to ID and Amount to Apply on each batch's open invoices, using the standard
    /// "Cust. Entry-Edit" codeunit to write the ledger entry. Returns the total marked.
    /// </summary>
    local procedure MarkInvoicesForApplication(ReceiptHeader: Record "PEN Receipt Header") AppliedAmount: Decimal
    var
        ReceiptLine: Record "PEN Receipt Line";
        Batch: Record "PEN Contribution Batch";
        CustLedgerEntry: Record "Cust. Ledger Entry";
        RemainingToApply: Decimal;
        AmountToApply: Decimal;
    begin
        ReceiptLine.SetRange("Receipt No.", ReceiptHeader."No.");
        ReceiptLine.SetFilter("Batch No.", '<>%1', '');
        if not ReceiptLine.FindSet() then
            exit(0);
        repeat
            Batch.Get(ReceiptLine."Batch No.");
            RemainingToApply := ReceiptLine.Amount;
            Batch.FilterOpenInvoices(CustLedgerEntry);
            CustLedgerEntry.SetAutoCalcFields("Remaining Amount");
            if CustLedgerEntry.FindSet() then
                repeat
                    AmountToApply := RemainingToApply;
                    if AmountToApply > CustLedgerEntry."Remaining Amount" then
                        AmountToApply := CustLedgerEntry."Remaining Amount";
                    if AmountToApply > 0 then begin
                        CustLedgerEntry."Applies-to ID" := ReceiptHeader."No.";
                        CustLedgerEntry."Amount to Apply" := AmountToApply;
                        Codeunit.Run(Codeunit::"Cust. Entry-Edit", CustLedgerEntry);
                        RemainingToApply -= AmountToApply;
                        AppliedAmount += AmountToApply;
                    end;
                until (CustLedgerEntry.Next() = 0) or (RemainingToApply <= 0);
        until ReceiptLine.Next() = 0;
    end;

    local procedure PostPayment(ReceiptHeader: Record "PEN Receipt Header"; AppliedAmount: Decimal)
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.Init();
        GenJournalLine."Posting Date" := ReceiptHeader."Receipt Date";
        GenJournalLine."Document Date" := ReceiptHeader."Receipt Date";
        GenJournalLine."Document Type" := GenJournalLine."Document Type"::Payment;
        GenJournalLine."Document No." := PostedReceiptNo;
        GenJournalLine."External Document No." := ReceiptHeader."Payment Reference";
        GenJournalLine."Account Type" := GenJournalLine."Account Type"::Customer;
        GenJournalLine.Validate("Account No.", ReceiptHeader."Employer No.");
        GenJournalLine."Bal. Account Type" := GenJournalLine."Bal. Account Type"::"Bank Account";
        GenJournalLine.Validate("Bal. Account No.", ReceiptHeader."Bank Account No.");
        GenJournalLine.Validate(Amount, -ReceiptHeader.Amount);
        if ReceiptHeader.Description <> '' then
            GenJournalLine.Description := ReceiptHeader.Description
        else
            GenJournalLine.Description := CopyStr(StrSubstNo(PaymentDescriptionTxt, ReceiptHeader."Employer No."), 1, MaxStrLen(GenJournalLine.Description));
        if AppliedAmount > 0 then
            GenJournalLine."Applies-to ID" := ReceiptHeader."No.";
        GenJournalLine."System-Created Entry" := true;

        OnBeforePostReceiptPayment(GenJournalLine, ReceiptHeader);
        GenJnlPostLine.RunWithCheck(GenJournalLine);
    end;

    local procedure CreatePostedReceipt(ReceiptHeader: Record "PEN Receipt Header"; AppliedAmount: Decimal; var PostedReceiptHeader: Record "PEN Posted Receipt Header")
    var
        ReceiptLine: Record "PEN Receipt Line";
        PostedReceiptLine: Record "PEN Posted Receipt Line";
    begin
        PostedReceiptHeader.Init();
        PostedReceiptHeader."No." := PostedReceiptNo;
        PostedReceiptHeader."Pre-Assigned No." := ReceiptHeader."No.";
        PostedReceiptHeader."Employer No." := ReceiptHeader."Employer No.";
        PostedReceiptHeader."Employer Name" := ReceiptHeader."Employer Name";
        PostedReceiptHeader."Receipt Date" := ReceiptHeader."Receipt Date";
        PostedReceiptHeader."Bank Account No." := ReceiptHeader."Bank Account No.";
        PostedReceiptHeader."Payment Reference" := ReceiptHeader."Payment Reference";
        PostedReceiptHeader.Amount := ReceiptHeader.Amount;
        PostedReceiptHeader."Applied Amount" := AppliedAmount;
        PostedReceiptHeader.Description := ReceiptHeader.Description;
        PostedReceiptHeader."Posted By" := CopyStr(UserId(), 1, MaxStrLen(PostedReceiptHeader."Posted By"));
        PostedReceiptHeader."Posted At" := CurrentDateTime();
        PostedReceiptHeader.Insert();

        ReceiptLine.SetRange("Receipt No.", ReceiptHeader."No.");
        if ReceiptLine.FindSet() then
            repeat
                PostedReceiptLine.Init();
                PostedReceiptLine."Receipt No." := PostedReceiptNo;
                PostedReceiptLine."Line No." := ReceiptLine."Line No.";
                PostedReceiptLine."Employer No." := ReceiptLine."Employer No.";
                PostedReceiptLine."Batch No." := ReceiptLine."Batch No.";
                PostedReceiptLine.Description := ReceiptLine.Description;
                PostedReceiptLine."Outstanding Amount" := ReceiptLine."Outstanding Amount";
                PostedReceiptLine.Amount := ReceiptLine.Amount;
                PostedReceiptLine.Insert();
            until ReceiptLine.Next() = 0;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostReceiptPayment(var GenJournalLine: Record "Gen. Journal Line"; ReceiptHeader: Record "PEN Receipt Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPostReceipt(PostedReceiptHeader: Record "PEN Posted Receipt Header")
    begin
    end;
}
