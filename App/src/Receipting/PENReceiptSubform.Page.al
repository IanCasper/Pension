namespace Zamara.Pension;

page 50117 "PEN Receipt Subform"
{
    Caption = 'Allocation';
    PageType = ListPart;
    SourceTable = "PEN Receipt Line";
    ApplicationArea = All;
    AutoSplitKey = true;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Batch No."; Rec."Batch No.") { ToolTip = 'Specifies the contribution batch this money pays. Leave it blank for a payment on account.'; }
                field(Description; Rec.Description) { ToolTip = 'Specifies a description of the allocation.'; }
                field("Outstanding Amount"; Rec."Outstanding Amount") { ToolTip = 'Specifies how much the employer still owes on the batch.'; }
                field(Amount; Rec.Amount) { ToolTip = 'Specifies the amount allocated to the batch.'; }
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    var
        ReceiptHeader: Record "PEN Receipt Header";
    begin
        if ReceiptHeader.Get(Rec.GetFilter("Receipt No.")) then
            Rec.InitFromHeader(ReceiptHeader);
    end;
}
