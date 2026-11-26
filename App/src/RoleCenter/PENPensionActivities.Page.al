namespace Zamara.Pension;

using Microsoft.Sales.Customer;

/// <summary>
/// Cues for the Pension Administrator role center. The cue counts are FlowFields on the
/// "PEN Pension Setup" record, which doubles as the cue table.
/// </summary>
page 50123 "PEN Pension Activities"
{
    Caption = 'Pension Activities';
    PageType = CardPart;
    SourceTable = "PEN Pension Setup";
    ApplicationArea = All;
    RefreshOnActivate = true;
    ShowFilter = false;

    layout
    {
        area(Content)
        {
            cuegroup(ContributionQueue)
            {
                Caption = 'Contribution Queue';
                field("Pending Lines"; Rec."Pending Lines")
                {
                    ToolTip = 'Specifies the number of contribution lines waiting to be processed.';
                    DrillDownPageId = "PEN Contribution Queue";
                }
                field("Processing Lines"; Rec."Processing Lines")
                {
                    ToolTip = 'Specifies the number of lines being processed by a running job right now.';
                    DrillDownPageId = "PEN Contribution Queue";
                }
                field("Failed Lines"; Rec."Failed Lines")
                {
                    ToolTip = 'Specifies the number of failed lines that will be retried on the next run.';
                    DrillDownPageId = "PEN Contribution Queue";
                    StyleExpr = FailedStyle;
                }
                field("Dead Letter Lines"; Rec."Dead Letter Lines")
                {
                    ToolTip = 'Specifies the number of lines that failed too many times and need a manual Reprocess.';
                    DrillDownPageId = "PEN Contribution Queue";
                    StyleExpr = DeadLetterStyle;
                }

                actions
                {
                    action(ImportFile)
                    {
                        Caption = 'Import Contribution File';
                        ToolTip = 'Uploads a contribution batch as a JSON or CSV file.';
                        Image = TileNew;
                        RunObject = codeunit "PEN Import Contribution File";
                    }
                    action(ProcessInBackground)
                    {
                        Caption = 'Process Queue in Background';
                        ToolTip = 'Starts a one-off Job Queue entry that processes all Pending lines.';
                        Image = TileReport;
                        RunObject = codeunit "PEN Schedule Queue Run";
                    }
                }
            }
            cuegroup(Batches)
            {
                Caption = 'Contribution Batches';
                field("Open Batches"; Rec."Open Batches")
                {
                    ToolTip = 'Specifies the number of batches that are received or in progress.';
                    DrillDownPageId = "PEN Contribution Batches";
                }
                field("Batches with Errors"; Rec."Batches with Errors")
                {
                    ToolTip = 'Specifies the number of batches that finished with Dead Letter lines.';
                    DrillDownPageId = "PEN Contribution Batches";
                    StyleExpr = BatchErrorStyle;
                }
                field("Late Batches"; Rec."Late Batches")
                {
                    ToolTip = 'Specifies the number of batches that were received late and charged a penalty.';
                    DrillDownPageId = "PEN Contribution Batches";
                }
            }
            cuegroup(Receivables)
            {
                Caption = 'Employer Receivables';
                field(OutstandingReceivable; OutstandingReceivable)
                {
                    Caption = 'Outstanding Contributions';
                    ToolTip = 'Specifies the total that pension employers still owe (contributions and penalties less receipts). Choose the amount to see the employers.';
                    AutoFormatType = 10;
                    AutoFormatExpression = '<Precision,0:0><Standard Format,0>';

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"PEN Employer List");
                    end;
                }
                field("Open Receipts"; Rec."Open Receipts")
                {
                    ToolTip = 'Specifies the number of receipts that are not posted yet.';
                    DrillDownPageId = "PEN Receipts";
                }

                actions
                {
                    action(NewReceipt)
                    {
                        Caption = 'New Receipt';
                        ToolTip = 'Records money received from an employer.';
                        Image = TileNew;
                        RunObject = page "PEN Receipt";
                        RunPageMode = Create;
                    }
                }
            }
            cuegroup(MasterData)
            {
                Caption = 'Scheme Membership';
                field("Active Members"; Rec."Active Members")
                {
                    ToolTip = 'Specifies the number of active members.';
                    DrillDownPageId = "PEN Member List";
                }
                field("Pension Employers"; Rec."Pension Employers")
                {
                    ToolTip = 'Specifies the number of pension employers.';
                    DrillDownPageId = "PEN Employer List";
                }
                field("Suspended Employers"; Rec."Suspended Employers")
                {
                    ToolTip = 'Specifies the number of suspended employers.';
                    DrillDownPageId = "PEN Employer List";
                }
                field(Schemes; Rec.Schemes)
                {
                    ToolTip = 'Specifies the number of pension schemes.';
                    DrillDownPageId = "PEN Schemes";
                }

                actions
                {
                    action(NewMember)
                    {
                        Caption = 'New Member';
                        ToolTip = 'Registers a new member.';
                        Image = TileNew;
                        RunObject = page "PEN Member Card";
                        RunPageMode = Create;
                    }
                    action(NewEmployer)
                    {
                        Caption = 'New Employer';
                        ToolTip = 'Registers a new pension employer.';
                        Image = TileNew;
                        RunObject = page "PEN Employer Card";
                        RunPageMode = Create;
                    }
                }
            }
            group(LastRun)
            {
                Caption = 'Last Processor Run';
                field(LastRunStartedAt; LastRunLog."Started At")
                {
                    Caption = 'Started At';
                    ToolTip = 'Specifies when the queue processor last ran. Choose the value to open the run log.';
                    Editable = false;

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"PEN Queue Run Log");
                    end;
                }
                field(LastRunLines; LastRunLog."Lines Claimed")
                {
                    Caption = 'Lines Processed';
                    ToolTip = 'Specifies how many lines the last run processed.';
                    Editable = false;
                }
                field(LastRunDuration; LastRunLog."Duration (ms)")
                {
                    Caption = 'Duration (ms)';
                    ToolTip = 'Specifies how long the last run took.';
                    Editable = false;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        Rec.GetSetup();
    end;

    trigger OnAfterGetRecord()
    begin
        CalculateCues();
    end;

    var
        LastRunLog: Record "PEN Queue Run Log";
        OutstandingReceivable: Decimal;
        FailedStyle: Text;
        DeadLetterStyle: Text;
        BatchErrorStyle: Text;

    local procedure CalculateCues()
    var
        Employer: Record Customer;
    begin
        Rec.CalcFields("Failed Lines", "Dead Letter Lines", "Batches with Errors");
        FailedStyle := StyleFor(Rec."Failed Lines", 'Ambiguous');
        DeadLetterStyle := StyleFor(Rec."Dead Letter Lines", 'Unfavorable');
        BatchErrorStyle := StyleFor(Rec."Batches with Errors", 'Unfavorable');

        OutstandingReceivable := 0;
        Employer.SetRange("PEN Pension Employer", true);
        Employer.SetAutoCalcFields("Balance (LCY)");
        Employer.SetLoadFields("No.");
        if Employer.FindSet() then
            repeat
                OutstandingReceivable += Employer."Balance (LCY)";
            until Employer.Next() = 0;

        Clear(LastRunLog);
        LastRunLog.SetCurrentKey("Started At");
        if LastRunLog.FindLast() then;
    end;

    local procedure StyleFor(Count: Integer; StyleWhenNonZero: Text): Text
    begin
        if Count > 0 then
            exit(StyleWhenNonZero);
        exit('Favorable');
    end;
}
