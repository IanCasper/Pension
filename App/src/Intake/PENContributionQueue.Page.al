namespace Zamara.Pension;

page 50109 "PEN Contribution Queue"
{
    Caption = 'Contribution Queue';
    PageType = List;
    SourceTable = "PEN Contribution Queue";
    UsageCategory = Lists;
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
                field("Batch No."; Rec."Batch No.") { ToolTip = 'Specifies the batch the line belongs to.'; }
                field("Line No."; Rec."Line No.") { ToolTip = 'Specifies the line number.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer.'; }
                field("Member No."; Rec."Member No.") { ToolTip = 'Specifies the member.'; }
                field("Member Name"; Rec."Member Name") { ToolTip = 'Specifies the member name.'; }
                field(Period; Rec.Period) { ToolTip = 'Specifies the contribution period.'; }
                field("Employee Amount"; Rec."Employee Amount") { ToolTip = 'Specifies the employee contribution.'; }
                field("Employer Amount"; Rec."Employer Amount") { ToolTip = 'Specifies the employer contribution.'; }
                field(Status; Rec.Status) { ToolTip = 'Specifies the processing status of the line.'; StyleExpr = StatusStyle; }
                field("Retry Count"; Rec."Retry Count") { ToolTip = 'Specifies how many times the line has failed.'; }
                field("Last Error"; Rec."Last Error") { ToolTip = 'Specifies the error from the last failed attempt.'; }
                field("Last Attempt At"; Rec."Last Attempt At") { ToolTip = 'Specifies when the line was last processed.'; }
                field("Claimed By Session ID"; Rec."Claimed By Session ID") { ToolTip = 'Specifies the session that is processing the line.'; Visible = false; }
                field("Claimed At"; Rec."Claimed At") { ToolTip = 'Specifies when the line was claimed for processing.'; Visible = false; }
                field("Posted Document No."; Rec."Posted Document No.") { ToolTip = 'Specifies the document number the line was posted with.'; }
                field("Posted At"; Rec."Posted At") { ToolTip = 'Specifies when the line was posted.'; }
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
        area(Navigation)
        {
            action(Batch)
            {
                Caption = 'Contribution Batch';
                ToolTip = 'Opens the batch the line belongs to.';
                Image = Document;
                RunObject = page "PEN Contribution Batch";
                RunPageLink = "No." = field("Batch No.");
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(Reprocess_Promoted; Reprocess) { }
                actionref(ShowError_Promoted; ShowError) { }
            }
        }
    }

    views
    {
        view(FailedLines)
        {
            Caption = 'Failed';
            Filters = where(Status = const(Failed));
        }
        view(DeadLetterLines)
        {
            Caption = 'Dead Letter';
            Filters = where(Status = const("Dead Letter"));
        }
        view(PendingLines)
        {
            Caption = 'Pending';
            Filters = where(Status = const(Pending));
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
