namespace Zamara.Pension;

page 50116 "PEN Receipt"
{
    Caption = 'Pension Receipt';
    PageType = Document;
    SourceTable = "PEN Receipt Header";
    UsageCategory = None;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the receipt number.';

                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer that paid.'; ShowMandatory = true; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field("Receipt Date"; Rec."Receipt Date") { ToolTip = 'Specifies the date the money was received. It is the posting date.'; ShowMandatory = true; }
                field("Bank Account No."; Rec."Bank Account No.") { ToolTip = 'Specifies the bank account the money was paid into.'; ShowMandatory = true; }
                field("Payment Reference"; Rec."Payment Reference") { ToolTip = 'Specifies the bank or cheque reference. It is posted as the external document number.'; }
                field(Description; Rec.Description) { ToolTip = 'Specifies a description for the receipt.'; }
                field(Amount; Rec.Amount) { ToolTip = 'Specifies the amount received.'; ShowMandatory = true; }
                field("Lines Total"; Rec."Lines Total") { ToolTip = 'Specifies the total allocated on the lines. It must equal the amount before posting.'; }
            }
            part(Lines; "PEN Receipt Subform")
            {
                Caption = 'Allocation';
                SubPageLink = "Receipt No." = field("No.");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SuggestLines)
            {
                Caption = 'Suggest Lines';
                ToolTip = 'Adds a line for each of the employer''s batches that still has an outstanding amount.';
                Image = SuggestLines;

                trigger OnAction()
                begin
                    Rec.SuggestLines();
                    CurrPage.Update(false);
                end;
            }
            action(SetAmountFromLines)
            {
                Caption = 'Set Amount from Lines';
                ToolTip = 'Sets the receipt amount to the total of the lines.';
                Image = UpdateUnitCost;

                trigger OnAction()
                begin
                    Rec.CalcFields("Lines Total");
                    Rec.Validate(Amount, Rec."Lines Total");
                    Rec.Modify(true);
                end;
            }
            action(Post)
            {
                Caption = 'Post';
                ToolTip = 'Posts the receipt: debits the bank, credits the employer and applies the payment to the batch invoices.';
                Image = PostOrder;
                ShortcutKey = 'F9';

                trigger OnAction()
                var
                    ReceiptPost: Codeunit "PEN Receipt-Post";
                begin
                    if not Confirm(PostQst, true, Rec."No.") then
                        exit;
                    ReceiptPost.Run(Rec);
                    Message(PostedMsg, ReceiptPost.GetPostedReceiptNo());
                    CurrPage.Close();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(SuggestLines_Promoted; SuggestLines) { }
                actionref(SetAmountFromLines_Promoted; SetAmountFromLines) { }
                actionref(Post_Promoted; Post) { }
            }
        }
    }

    var
        PostQst: Label 'Do you want to post receipt %1?', Comment = '%1 = receipt no.';
        PostedMsg: Label 'The receipt was posted as %1.', Comment = '%1 = posted receipt no.';
}
