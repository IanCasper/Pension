namespace Zamara.Pension;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.Customer;
using System.Threading;

/// <summary>
/// Shared helpers: contribution periods and due dates, reprocessing, batch status,
/// reconciliation and Job Queue setup.
/// </summary>
codeunit 50104 "PEN Pension Mgt"
{
    var
        InvalidPeriodErr: Label 'Period %1 is not valid. Use the format YYYY-MM, for example 2026-10.', Comment = '%1 = period text';
        JobQueueDescriptionTxt: Label 'Process pension contribution queue';
        JobQueueOneOffDescriptionTxt: Label 'Process pension contribution queue (one-off)';
        ReconciledMsg: Label 'Batch %1 reconciles.\Member ledger: %2\Employer invoice: %3\G/L credit to Member Liability (%4): %5', Comment = '%1 = batch, %2 = MLE total, %3 = invoice total, %4 = account, %5 = G/L credit';
        NotReconciledMsg: Label 'Batch %1 does NOT reconcile.\Member ledger: %2\Employer invoice: %3\G/L credit to Member Liability (%4): %5', Comment = '%1 = batch, %2 = MLE total, %3 = invoice total, %4 = account, %5 = G/L credit';

    /// <summary>
    /// Parses a period in the format YYYY-MM. Returns false instead of raising an error,
    /// so intake can report a structural error with context.
    /// </summary>
    procedure TryParsePeriod(PeriodText: Text; var PeriodStart: Date; var PeriodEnd: Date): Boolean
    var
        Year: Integer;
        Month: Integer;
    begin
        PeriodStart := 0D;
        PeriodEnd := 0D;
        if StrLen(PeriodText) <> 7 then
            exit(false);
        if CopyStr(PeriodText, 5, 1) <> '-' then
            exit(false);
        if DelChr(CopyStr(PeriodText, 1, 4) + CopyStr(PeriodText, 6, 2), '=', '0123456789') <> '' then
            exit(false);
        Evaluate(Year, CopyStr(PeriodText, 1, 4));
        Evaluate(Month, CopyStr(PeriodText, 6, 2));
        if (Year < 1900) or (Month < 1) or (Month > 12) then
            exit(false);
        PeriodStart := DMY2Date(1, Month, Year);
        PeriodEnd := CalcDate('<CM>', PeriodStart);
        exit(true);
    end;

    /// <summary>
    /// Last day of the contribution period. This is the posting date of member ledger entries and contribution invoices.
    /// </summary>
    procedure GetPeriodEndDate(Period: Code[7]): Date
    var
        PeriodStart: Date;
        PeriodEnd: Date;
    begin
        if not TryParsePeriod(Period, PeriodStart, PeriodEnd) then
            Error(InvalidPeriodErr, Period);
        exit(PeriodEnd);
    end;

    /// <summary>
    /// Day "DueDay" of the month after the period. A due day past the end of that month
    /// (for example 31 in November) moves to the month's last day.
    /// </summary>
    procedure GetDueDate(Period: Code[7]; DueDay: Integer): Date
    var
        PeriodStart: Date;
        PeriodEnd: Date;
        NextMonthStart: Date;
        LastDayOfNextMonth: Integer;
    begin
        if not TryParsePeriod(Period, PeriodStart, PeriodEnd) then
            Error(InvalidPeriodErr, Period);
        NextMonthStart := PeriodEnd + 1;
        LastDayOfNextMonth := Date2DMY(CalcDate('<CM>', NextMonthStart), 1);
        if DueDay > LastDayOfNextMonth then
            DueDay := LastDayOfNextMonth;
        if DueDay < 1 then
            DueDay := 1;
        exit(DMY2Date(DueDay, Date2DMY(NextMonthStart, 2), Date2DMY(NextMonthStart, 3)));
    end;

    procedure IsBatchLate(Batch: Record "PEN Contribution Batch"): Boolean
    begin
        exit(Batch."Received Date" > Batch."Due Date");
    end;

    procedure CalcPenaltyAmount(Batch: Record "PEN Contribution Batch"; PensionSetup: Record "PEN Pension Setup"): Decimal
    begin
        exit(Round(Batch."Control Total" * PensionSetup."Late Penalty %" / 100));
    end;

    /// <summary>
    /// Resets selected Failed or Dead Letter lines to Pending with a fresh retry count.
    /// Lines in any other status are skipped. Returns the number of lines reset.
    /// </summary>
    procedure ReprocessLines(var SelectedLines: Record "PEN Contribution Queue") LinesReset: Integer
    var
        QueueLine: Record "PEN Contribution Queue";
        TouchedBatches: List of [Code[20]];
    begin
        if SelectedLines.FindSet() then
            repeat
                if SelectedLines.Status in [SelectedLines.Status::Failed, SelectedLines.Status::"Dead Letter"] then begin
                    QueueLine.ReadIsolation := IsolationLevel::UpdLock;
                    QueueLine.Get(SelectedLines."Batch No.", SelectedLines."Line No.");
                    if QueueLine.Status in [QueueLine.Status::Failed, QueueLine.Status::"Dead Letter"] then begin
                        QueueLine.Status := QueueLine.Status::Pending;
                        QueueLine."Retry Count" := 0;
                        QueueLine."Last Error" := '';
                        ClearClaim(QueueLine);
                        QueueLine.Modify();
                        LinesReset += 1;
                        if not TouchedBatches.Contains(QueueLine."Batch No.") then
                            TouchedBatches.Add(QueueLine."Batch No.");
                    end;
                end;
            until SelectedLines.Next() = 0;
        UpdateBatchStatuses(TouchedBatches);
    end;

    /// <summary>
    /// Records a failed attempt on a queue line: increases the retry count, stores the error and
    /// moves the line to Dead Letter once it has failed more than MaxRetryAttempts times
    /// (one first attempt plus MaxRetryAttempts retries). Returns true when the line went to Dead Letter.
    /// </summary>
    procedure MarkLineFailed(var QueueLine: Record "PEN Contribution Queue"; ErrorText: Text; MaxRetryAttempts: Integer) IsDeadLetter: Boolean
    begin
        QueueLine."Retry Count" += 1;
        QueueLine."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(QueueLine."Last Error"));
        QueueLine."Last Attempt At" := CurrentDateTime();
        ClearClaim(QueueLine);
        IsDeadLetter := QueueLine."Retry Count" > MaxRetryAttempts;
        if IsDeadLetter then
            QueueLine.Status := QueueLine.Status::"Dead Letter"
        else
            QueueLine.Status := QueueLine.Status::Failed;
        QueueLine.Modify();
    end;

    procedure IsClaimedByThisSession(QueueLine: Record "PEN Contribution Queue"): Boolean
    begin
        exit((QueueLine.Status = QueueLine.Status::Processing) and
             (QueueLine."Claimed By Session ID" = SessionId()) and
             (QueueLine."Claimed By Server Inst. ID" = ServiceInstanceId()));
    end;

    procedure ClearClaim(var QueueLine: Record "PEN Contribution Queue")
    begin
        QueueLine."Claimed By Session ID" := 0;
        QueueLine."Claimed By Server Inst. ID" := 0;
        QueueLine."Claimed At" := 0DT;
    end;

    procedure UpdateBatchStatuses(BatchNos: List of [Code[20]])
    var
        BatchNo: Code[20];
    begin
        foreach BatchNo in BatchNos do
            UpdateBatchStatus(BatchNo);
    end;

    procedure UpdateBatchStatus(BatchNo: Code[20])
    var
        Batch: Record "PEN Contribution Batch";
        OldStatus: Enum "PEN Batch Status";
    begin
        Batch.ReadIsolation := IsolationLevel::UpdLock;
        if not Batch.Get(BatchNo) then
            exit;
        OldStatus := Batch.Status;
        Batch.UpdateStatus();
        if Batch.Status <> OldStatus then
            Batch.Modify();
    end;

    /// <summary>
    /// Checks that, for one batch, the member ledger total equals the contribution invoice
    /// on the employer and equals the G/L credit to the scheme's Member Liability account.
    /// </summary>
    procedure CheckReconciliation(Batch: Record "PEN Contribution Batch"; ShowResult: Boolean): Boolean
    var
        Employer: Record Customer;
        GLEntry: Record "G/L Entry";
        Scheme: Record "PEN Scheme";
        LiabilityCredit: Decimal;
        Reconciled: Boolean;
    begin
        Batch.CalcFields("Member Ledger Amount", "Invoiced Amount");
        Employer.Get(Batch."Employer No.");
        Scheme.Get(Employer."PEN Scheme Code");
        GLEntry.SetRange("Document No.", Batch."No.");
        GLEntry.SetRange("G/L Account No.", Scheme."Member Liability Acc.");
        GLEntry.CalcSums(Amount);
        LiabilityCredit := -GLEntry.Amount;
        Reconciled := (Batch."Member Ledger Amount" = Batch."Invoiced Amount") and (Batch."Member Ledger Amount" = LiabilityCredit);
        if ShowResult then
            if Reconciled then
                Message(ReconciledMsg, Batch."No.", Batch."Member Ledger Amount", Batch."Invoiced Amount", Scheme."Member Liability Acc.", LiabilityCredit)
            else
                Message(NotReconciledMsg, Batch."No.", Batch."Member Ledger Amount", Batch."Invoiced Amount", Scheme."Member Liability Acc.", LiabilityCredit);
        exit(Reconciled);
    end;

    /// <summary>
    /// Creates a Job Queue entry for the queue processor. A recurring entry runs every minute;
    /// a one-off entry runs once in the background. No Job Queue category is set, because a
    /// category would serialise entries and prevent the parallel-processing demo.
    /// </summary>
    procedure CreateJobQueueEntry(Recurring: Boolean)
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"PEN Queue Processor";
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();
        JobQueueEntry."Maximum No. of Attempts to Run" := 3;
        JobQueueEntry."Rerun Delay (sec.)" := 30;
        if Recurring then begin
            JobQueueEntry.Description := JobQueueDescriptionTxt;
            JobQueueEntry."Recurring Job" := true;
            JobQueueEntry."Run on Mondays" := true;
            JobQueueEntry."Run on Tuesdays" := true;
            JobQueueEntry."Run on Wednesdays" := true;
            JobQueueEntry."Run on Thursdays" := true;
            JobQueueEntry."Run on Fridays" := true;
            JobQueueEntry."Run on Saturdays" := true;
            JobQueueEntry."Run on Sundays" := true;
            JobQueueEntry."No. of Minutes between Runs" := 1;
        end else
            JobQueueEntry.Description := JobQueueOneOffDescriptionTxt;
        Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
    end;
}
