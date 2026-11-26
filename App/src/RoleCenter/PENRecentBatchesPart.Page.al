namespace Zamara.Pension;

/// <summary>
/// The most recently received contribution batches, for the role center.
/// </summary>
page 50124 "PEN Recent Batches Part"
{
    Caption = 'Recent Contribution Batches';
    PageType = ListPart;
    SourceTable = "PEN Contribution Batch";
    SourceTableView = sorting("No.") order(descending);
    CardPageId = "PEN Contribution Batch";
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the batch number.';

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"PEN Contribution Batch", Rec);
                    end;
                }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer that sent the batch.'; }
                field(Period; Rec.Period) { ToolTip = 'Specifies the contribution period.'; }
                field("Control Total"; Rec."Control Total") { ToolTip = 'Specifies the control total from the file.'; }
                field(Status; Rec.Status) { ToolTip = 'Specifies the processing status of the batch.'; StyleExpr = StatusStyle; }
                field("Posted Lines"; Rec."Posted Lines") { ToolTip = 'Specifies the number of posted lines.'; }
                field("Failed Lines"; Rec."Failed Lines") { ToolTip = 'Specifies the number of failed lines that will be retried.'; }
                field("Dead Letter Lines"; Rec."Dead Letter Lines") { ToolTip = 'Specifies the number of lines that need a manual Reprocess.'; }
                field("Penalty Posted"; Rec."Penalty Posted") { ToolTip = 'Specifies that a late remittance penalty has been invoiced.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenAll)
            {
                Caption = 'All Batches';
                ToolTip = 'Opens the full list of contribution batches.';
                Image = List;
                RunObject = page "PEN Contribution Batches";
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Posted:
                StatusStyle := 'Favorable';
            Rec.Status::"Completed with Errors":
                StatusStyle := 'Unfavorable';
            Rec.Status::"In Progress":
                StatusStyle := 'Ambiguous';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
