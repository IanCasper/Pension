namespace Zamara.Pension;

using Microsoft.Bank.Ledger;
using Microsoft.Sales.Receivables;

page 50119 "PEN Posted Receipt"
{
    Caption = 'Posted Pension Receipt';
    PageType = Document;
    SourceTable = "PEN Posted Receipt Header";
    UsageCategory = None;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.") { ToolTip = 'Specifies the posted receipt number. It is the document number of the payment.'; }
                field("Pre-Assigned No."; Rec."Pre-Assigned No.") { ToolTip = 'Specifies the number the receipt had before posting.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer that paid.'; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field("Receipt Date"; Rec."Receipt Date") { ToolTip = 'Specifies the posting date.'; }
                field("Bank Account No."; Rec."Bank Account No.") { ToolTip = 'Specifies the bank account the money was paid into.'; }
                field("Payment Reference"; Rec."Payment Reference") { ToolTip = 'Specifies the bank or cheque reference.'; }
                field(Description; Rec.Description) { ToolTip = 'Specifies a description for the receipt.'; }
                field(Amount; Rec.Amount) { ToolTip = 'Specifies the amount received.'; }
                field("Applied Amount"; Rec."Applied Amount") { ToolTip = 'Specifies how much was applied to batch invoices. The rest is on account.'; }
                field("Posted By"; Rec."Posted By") { ToolTip = 'Specifies who posted the receipt.'; }
                field("Posted At"; Rec."Posted At") { ToolTip = 'Specifies when the receipt was posted.'; }
            }
            part(Lines; "PEN Posted Receipt Subform")
            {
                Caption = 'Allocation';
                SubPageLink = "Receipt No." = field("No.");
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(CustomerEntries)
            {
                Caption = 'Employer Ledger Entries';
                ToolTip = 'Shows the payment in the employer''s customer ledger.';
                Image = CustomerLedger;
                RunObject = page "Customer Ledger Entries";
                RunPageLink = "Customer No." = field("Employer No."), "Document No." = field("No.");
            }
            action(BankEntries)
            {
                Caption = 'Bank Ledger Entries';
                ToolTip = 'Shows the bank account ledger entry for this receipt.';
                Image = BankAccountLedger;
                RunObject = page "Bank Account Ledger Entries";
                RunPageLink = "Bank Account No." = field("Bank Account No."), "Document No." = field("No.");
            }
        }
        area(Promoted)
        {
            group(Category_Navigate)
            {
                Caption = 'Entries';
                actionref(CustomerEntries_Promoted; CustomerEntries) { }
                actionref(BankEntries_Promoted; BankEntries) { }
            }
        }
    }
}
