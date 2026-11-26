namespace Zamara.Pension;

page 50108 "PEN Contribution Queue Subform"
{
    Caption = 'Lines';
    PageType = ListPart;
    SourceTable = "PEN Contribution Queue";
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
                field("Line No."; Rec."Line No.") { ToolTip = 'Specifies the line number.'; }
                field("Member No."; Rec."Member No.") { ToolTip = 'Specifies the member.'; }
                field("Member Name"; Rec."Member Name") { ToolTip = 'Specifies the member name.'; }
                field("Employee Amount"; Rec."Employee Amount") { ToolTip = 'Specifies the employee contribution.'; }
                field("Employer Amount"; Rec."Employer Amount") { ToolTip = 'Specifies the employer contribution.'; }
                field("Line Amount"; Rec."Line Amount") { ToolTip = 'Specifies the total of the line.'; }
                field(Status; Rec.Status) { ToolTip = 'Specifies the processing status of the line.'; StyleExpr = StatusStyle; }
                field("Retry Count"; Rec."Retry Count") { ToolTip = 'Specifies how many times the line has failed.'; }
                field("Last Error"; Rec."Last Error") { ToolTip = 'Specifies the error from the last failed attempt.'; }
                field("Last Attempt At"; Rec."Last Attempt At") { ToolTip = 'Specifies when the line was last processed.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Reprocess)
            {
                Caption = 'Reprocess';
                ToolTip = 'Resets the selected Failed or Dead Letter lines to Pending with a fresh retry count.';
                Image = Refresh;

                trigger OnAction()
                var
                    QueueLine: Record "PEN Contribution Queue";
                    PensionMgt: Codeunit "PEN Pension Mgt";
                begin
                    CurrPage.SetSelectionFilter(QueueLine);
                    Message(LinesResetMsg, PensionMgt.ReprocessLines(QueueLine));
                    CurrPage.Update(false);
                end;
            }
            action(ShowError)
            {
                Caption = 'Show Error';
                ToolTip = 'Shows the full error text of the selected line.';
                Image = ErrorLog;

                trigger OnAction()
                begin
                    Message(Rec."Last Error");
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Posted:
                StatusStyle := 'Favorable';
            Rec.Status::Failed:
                StatusStyle := 'Attention';
            Rec.Status::"Dead Letter":
                StatusStyle := 'Unfavorable';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
        LinesResetMsg: Label '%1 lines were reset to Pending.', Comment = '%1 = number of lines';
}
