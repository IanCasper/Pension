namespace Zamara.Pension;

page 50113 "PEN Queue Run Log"
{
    Caption = 'Contribution Queue Run Log';
    PageType = List;
    SourceTable = "PEN Queue Run Log";
    SourceTableView = sorting("Entry No.") order(descending);
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field("Entry No."; Rec."Entry No.") { ToolTip = 'Specifies the run number.'; }
                field("Started At"; Rec."Started At") { ToolTip = 'Specifies when the run started.'; }
                field("Finished At"; Rec."Finished At") { ToolTip = 'Specifies when the run finished. Blank means the run is still going or stopped with an error.'; }
                field("Duration (ms)"; Rec."Duration (ms)") { ToolTip = 'Specifies how long the run took.'; }
                field("Session ID"; Rec."Session ID") { ToolTip = 'Specifies the session that ran. Two sessions overlapping in time show parallel processing.'; }
                field("Server Instance ID"; Rec."Server Instance ID") { ToolTip = 'Specifies the server instance that ran.'; }
                field("User ID"; Rec."User ID") { ToolTip = 'Specifies the user the run ran as.'; }
                field("Batch Size"; Rec."Batch Size") { ToolTip = 'Specifies the chunk size used.'; }
                field(Chunks; Rec.Chunks) { ToolTip = 'Specifies how many chunks (transactions) the run processed.'; }
                field("Lines Claimed"; Rec."Lines Claimed") { ToolTip = 'Specifies how many lines the run processed.'; }
                field("Lines Posted"; Rec."Lines Posted") { ToolTip = 'Specifies how many lines were posted.'; }
                field("Lines Failed"; Rec."Lines Failed") { ToolTip = 'Specifies how many lines failed and will be retried.'; }
                field("Lines Dead Letter"; Rec."Lines Dead Letter") { ToolTip = 'Specifies how many lines moved to Dead Letter.'; }
                field("Lines Reset"; Rec."Lines Reset") { ToolTip = 'Specifies how many stale or failed lines were reset to Pending at the start of the run.'; }
                field("Lines per Second"; Rec."Lines per Second") { ToolTip = 'Specifies the throughput.'; }
                field("Batch Filter"; Rec."Batch Filter") { ToolTip = 'Specifies the batch the run was limited to, if any.'; }
            }
        }
    }
}
