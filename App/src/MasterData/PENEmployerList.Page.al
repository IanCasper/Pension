namespace Zamara.Pension;

using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;

/// <summary>
/// Pension employers. Employers are standard customers flagged as "Pension Employer".
/// </summary>
page 50102 "PEN Employer List"
{
    Caption = 'Pension Employers';
    PageType = List;
    SourceTable = Customer;
    SourceTableView = where("PEN Pension Employer" = const(true));
    CardPageId = "PEN Employer Card";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ToolTip = 'Specifies the employer number. It is also the customer number.'; }
                field(Name; Rec.Name) { ToolTip = 'Specifies the employer name.'; }
                field("PEN Scheme Code"; Rec."PEN Scheme Code") { ToolTip = 'Specifies the scheme the employer belongs to.'; }
                field("PEN KRA PIN"; Rec."PEN KRA PIN") { ToolTip = 'Specifies the employer''s KRA PIN.'; }
                field("E-Mail"; Rec."E-Mail") { ToolTip = 'Specifies the employer''s email address.'; }
                field("PEN Employer Status"; Rec."PEN Employer Status") { ToolTip = 'Specifies whether the employer is active or suspended.'; }
                field("PEN Member Count"; Rec."PEN Member Count") { ToolTip = 'Specifies the number of active members.'; }
                field("Balance (LCY)"; Rec."Balance (LCY)") { ToolTip = 'Specifies the amount the employer owes: invoiced contributions and penalties less receipts.'; }
                field("Balance Due (LCY)"; Rec."Balance Due (LCY)") { ToolTip = 'Specifies the overdue amount.'; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Members)
            {
                Caption = 'Members';
                ToolTip = 'Shows the employer''s members.';
                Image = Employee;
                RunObject = page "PEN Member List";
                RunPageLink = "Employer No." = field("No.");
            }
            action(Batches)
            {
                Caption = 'Contribution Batches';
                ToolTip = 'Shows the contribution batches received from the employer.';
                Image = Documents;
                RunObject = page "PEN Contribution Batches";
                RunPageLink = "Employer No." = field("No.");
            }
            action(LedgerEntries)
            {
                Caption = 'Ledger Entries';
                ToolTip = 'Shows the employer''s customer ledger entries: contribution invoices, penalties and receipts.';
                Image = CustomerLedger;
                RunObject = page "Customer Ledger Entries";
                RunPageLink = "Customer No." = field("No.");
                RunPageView = sorting("Customer No.", "Posting Date") order(descending);
                ShortcutKey = 'Ctrl+F7';
            }
        }
        area(Promoted)
        {
            group(Category_Navigate)
            {
                Caption = 'Employer';
                actionref(Members_Promoted; Members) { }
                actionref(Batches_Promoted; Batches) { }
                actionref(LedgerEntries_Promoted; LedgerEntries) { }
            }
        }
    }
}
