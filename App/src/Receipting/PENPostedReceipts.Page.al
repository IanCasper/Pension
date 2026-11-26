namespace Zamara.Pension;

page 50118 "PEN Posted Receipts"
{
    Caption = 'Posted Pension Receipts';
    PageType = List;
    SourceTable = "PEN Posted Receipt Header";
    SourceTableView = sorting("No.") order(descending);
    CardPageId = "PEN Posted Receipt";
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ToolTip = 'Specifies the posted receipt number. It is the document number of the payment.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer that paid.'; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field("Receipt Date"; Rec."Receipt Date") { ToolTip = 'Specifies the posting date.'; }
                field("Bank Account No."; Rec."Bank Account No.") { ToolTip = 'Specifies the bank account the money was paid into.'; }
                field("Payment Reference"; Rec."Payment Reference") { ToolTip = 'Specifies the bank or cheque reference.'; }
                field(Amount; Rec.Amount) { ToolTip = 'Specifies the amount received.'; }
                field("Applied Amount"; Rec."Applied Amount") { ToolTip = 'Specifies how much was applied to batch invoices. The rest is on account.'; }
                field("Posted By"; Rec."Posted By") { ToolTip = 'Specifies who posted the receipt.'; }
                field("Posted At"; Rec."Posted At") { ToolTip = 'Specifies when the receipt was posted.'; }
            }
        }
    }
}
