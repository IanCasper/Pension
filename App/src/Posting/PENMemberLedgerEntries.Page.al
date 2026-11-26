namespace Zamara.Pension;

page 50110 "PEN Member Ledger Entries"
{
    Caption = 'Member Ledger Entries';
    PageType = List;
    SourceTable = "PEN Member Ledger Entry";
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Posting Date"; Rec."Posting Date") { ToolTip = 'Specifies the posting date: the last day of the contribution period.'; }
                field(Period; Rec.Period) { ToolTip = 'Specifies the contribution period.'; }
                field("Member No."; Rec."Member No.") { ToolTip = 'Specifies the member.'; }
                field("Member Name"; Rec."Member Name") { ToolTip = 'Specifies the member name.'; }
                field("Entry Type"; Rec."Entry Type") { ToolTip = 'Specifies whether the entry is the employee or the employer share.'; }
                field(Amount; Rec.Amount) { ToolTip = 'Specifies the contribution amount.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer that paid the contribution.'; }
                field("Scheme Code"; Rec."Scheme Code") { ToolTip = 'Specifies the scheme.'; }
                field("Batch No."; Rec."Batch No.") { ToolTip = 'Specifies the contribution batch the entry came from.'; }
                field("Document No."; Rec."Document No.") { ToolTip = 'Specifies the document number. It is the same as the document number of the employer invoice and G/L entries.'; }
                field("Posted By"; Rec."Posted By") { ToolTip = 'Specifies who posted the entry.'; }
                field("Posted At"; Rec."Posted At") { ToolTip = 'Specifies when the entry was posted.'; }
                field("Entry No."; Rec."Entry No.") { ToolTip = 'Specifies the entry number.'; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Batch)
            {
                Caption = 'Contribution Batch';
                ToolTip = 'Opens the batch the entry came from.';
                Image = Document;
                RunObject = page "PEN Contribution Batch";
                RunPageLink = "No." = field("Batch No.");
            }
        }
    }
}
