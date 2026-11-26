namespace Zamara.Pension;

page 50120 "PEN Posted Receipt Subform"
{
    Caption = 'Allocation';
    PageType = ListPart;
    SourceTable = "PEN Posted Receipt Line";
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Batch No."; Rec."Batch No.") { ToolTip = 'Specifies the contribution batch this money paid. Blank means a payment on account.'; }
                field(Description; Rec.Description) { ToolTip = 'Specifies a description of the allocation.'; }
                field("Outstanding Amount"; Rec."Outstanding Amount") { ToolTip = 'Specifies how much the employer owed on the batch before this receipt.'; }
                field(Amount; Rec.Amount) { ToolTip = 'Specifies the amount allocated to the batch.'; }
            }
        }
    }
}
