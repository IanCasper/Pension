namespace Zamara.Pension;

using Microsoft.Sales.Customer;

/// <summary>
/// Queue monitor: line counts by status, the last processor run and the most common errors.
/// </summary>
page 50112 "PEN Queue Monitor"
{
    Caption = 'Contribution Queue Monitor';
    PageType = Card;
    SourceTable = "PEN Pension Setup";
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            cuegroup(QueueStatus)
            {
                Caption = 'Queue Lines by Status';
                field("Pending Lines"; Rec."Pending Lines") { ToolTip = 'Specifies the number of lines waiting to be processed.'; }
                field("Processing Lines"; Rec."Processing Lines") { ToolTip = 'Specifies the number of lines claimed by a running job.'; }
                field("Posted Lines"; Rec."Posted Lines") { ToolTip = 'Specifies the number of posted lines.'; }
                field("Failed Lines"; Rec."Failed Lines") { ToolTip = 'Specifies the number of failed lines that will be retried.'; Style = Attention; }
                field("Dead Letter Lines"; Rec."Dead Letter Lines") { ToolTip = 'Specifies the number of lines that need a manual Reprocess.'; Style = Unfavorable; }
            }
            cuegroup(Documents)
            {
                Caption = 'Documents';
                field("Open Batches"; Rec."Open Batches")
                {
                    ToolTip = 'Specifies the number of batches that are received or in progress.';
                    DrillDownPageId = "PEN Contribution Batches";
                }
                field("Open Receipts"; Rec."Open Receipts")
                {
                    ToolTip = 'Specifies the number of receipts that are not posted yet.';
                    DrillDownPageId = "PEN Receipts";
                }
            }
            group(LastRun)
            {
                Caption = 'Last Run';
                field(LastRunStartedAt; LastRunLog."Started At")
                {
                    Caption = 'Started At';
                    ToolTip = 'Specifies when the processor last ran.';
                    Editable = false;
                }
                field(LastRunDuration; LastRunLog."Duration (ms)")
                {
                    Caption = 'Duration (ms)';
                    ToolTip = 'Specifies how long the last run took.';
                    Editable = false;
                }
                field(LastRunLines; LastRunLog."Lines Claimed")
                {
                    Caption = 'Lines Processed';
                    ToolTip = 'Specifies how many lines the last run processed.';
                    Editable = false;
                }
                field(LastRunRate; LastRunLog."Lines per Second")
                {
                    Caption = 'Lines per Second';
                    ToolTip = 'Specifies the throughput of the last run.';
                    Editable = false;
                }
                field(LastRunSession; LastRunLog."Session ID")
                {
                    Caption = 'Session ID';
                    ToolTip = 'Specifies the session that ran the last run.';
                    Editable = false;
                }
                field(OutstandingReceivable; OutstandingReceivable)
                {
                    Caption = 'Outstanding Employer Receivable';
                    ToolTip = 'Specifies the total that pension employers still owe (contributions and penalties less receipts).';
                    AutoFormatType = 1;
                    Editable = false;
                }
            }
            part(TopErrors; "PEN Top Errors Part")
            {
                Caption = 'Most Common Errors';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshMonitor)
            {
                Caption = 'Refresh';
                ToolTip = 'Recalculates the monitor.';
                Image = Refresh;

                trigger OnAction()
                begin
                    LoadStatistics();
                    CurrPage.TopErrors.Page.LoadTopErrors();
                    CurrPage.Update(false);
                end;
            }
            action(ProcessInBackground)
            {
                Caption = 'Process Queue in Background';
                ToolTip = 'Starts a one-off Job Queue entry that processes all Pending lines.';
                Image = ExecuteBatch;

                trigger OnAction()
                var
                    PensionMgt: Codeunit "PEN Pension Mgt";
                begin
                    PensionMgt.CreateJobQueueEntry(false);
                end;
            }
        }
        area(Navigation)
        {
            action(RunLog)
            {
                Caption = 'Run Log';
                ToolTip = 'Shows every processor run with its duration and counts.';
                Image = Log;
                RunObject = page "PEN Queue Run Log";
            }
            action(DeadLetter)
            {
                Caption = 'Dead Letter Lines';
                ToolTip = 'Shows the lines that need a manual Reprocess.';
                Image = ErrorLog;
                RunObject = page "PEN Contribution Queue";
                RunPageView = where(Status = const("Dead Letter"));
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(RefreshMonitor_Promoted; RefreshMonitor) { }
                actionref(ProcessInBackground_Promoted; ProcessInBackground) { }
                actionref(RunLog_Promoted; RunLog) { }
                actionref(DeadLetter_Promoted; DeadLetter) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        Rec.GetSetup();
        LoadStatistics();
    end;

    trigger OnAfterGetRecord()
    begin
        LoadStatistics();
    end;

    var
        LastRunLog: Record "PEN Queue Run Log";
        OutstandingReceivable: Decimal;

    local procedure LoadStatistics()
    var
        Employer: Record Customer;
    begin
        Clear(LastRunLog);
        LastRunLog.SetCurrentKey("Started At");
        if LastRunLog.FindLast() then;

        OutstandingReceivable := 0;
        Employer.SetRange("PEN Pension Employer", true);
        Employer.SetAutoCalcFields("Balance (LCY)");
        Employer.SetLoadFields("No.");
        if Employer.FindSet() then
            repeat
                OutstandingReceivable += Employer."Balance (LCY)";
            until Employer.Next() = 0;
    end;
}
