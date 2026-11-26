namespace Zamara.Pension;

page 50115 "PEN Receipts"
{
    Caption = 'Pension Receipts';
    PageType = List;
    SourceTable = "PEN Receipt Header";
    CardPageId = "PEN Receipt";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ToolTip = 'Specifies the receipt number.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer that paid.'; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field("Receipt Date"; Rec."Receipt Date") { ToolTip = 'Specifies the date the money was received. It is the posting date.'; }
                field("Bank Account No."; Rec."Bank Account No.") { ToolTip = 'Specifies the bank account the money was paid into.'; }
                field("Payment Reference"; Rec."Payment Reference") { ToolTip = 'Specifies the bank or cheque reference.'; }
                field(Amount; Rec.Amount) { ToolTip = 'Specifies the amount received.'; }
                field("Lines Total"; Rec."Lines Total") { ToolTip = 'Specifies the total allocated on the lines. It must equal the amount before posting.'; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(PostedReceipts)
            {
                Caption = 'Posted Receipts';
                ToolTip = 'Shows posted receipts.';
                Image = PostedReceipts;
                RunObject = page "PEN Posted Receipts";
            }
        }
    }
}
