namespace Zamara.Pension;

using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;

/// <summary>
/// Card for a pension employer. The record is a standard customer, so the employer's
/// invoices, penalties and receipts appear in the customer ledger.
/// </summary>
page 50103 "PEN Employer Card"
{
    Caption = 'Pension Employer';
    PageType = Card;
    SourceTable = Customer;
    SourceTableView = where("PEN Pension Employer" = const(true));
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
                    ToolTip = 'Specifies the employer number. It is also the customer number.';
                    Editable = false;
                }
                field(Name; Rec.Name)
                {
                    ToolTip = 'Specifies the employer name.';
                    ShowMandatory = true;
                }
                field("PEN Scheme Code"; Rec."PEN Scheme Code")
                {
                    ToolTip = 'Specifies the scheme the employer belongs to. Its members join this scheme.';
                    ShowMandatory = true;
                }
                field("PEN KRA PIN"; Rec."PEN KRA PIN")
                {
                    ToolTip = 'Specifies the employer''s KRA PIN, in the format A000000000Z.';
                    ShowMandatory = true;
                }
                field("E-Mail"; Rec."E-Mail")
                {
                    ToolTip = 'Specifies the employer''s email address.';
                    ExtendedDatatype = EMail;
                }
                field("PEN Employer Status"; Rec."PEN Employer Status")
                {
                    ToolTip = 'Specifies whether the employer is active. A suspended employer cannot take new members or contributions.';
                }
                field("PEN Member Count"; Rec."PEN Member Count")
                {
                    ToolTip = 'Specifies the number of active members.';
                }
            }
            group(Receivables)
            {
                Caption = 'Receivables';
                field("Customer Posting Group"; Rec."Customer Posting Group")
                {
                    ToolTip = 'Specifies the customer posting group. It is set from the scheme.';
                    Editable = false;
                }
                field("Balance (LCY)"; Rec."Balance (LCY)")
                {
                    ToolTip = 'Specifies the amount the employer owes: invoiced contributions and penalties less receipts.';
                }
                field("Balance Due (LCY)"; Rec."Balance Due (LCY)")
                {
                    ToolTip = 'Specifies the overdue amount.';
                }
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
            action(Receipts)
            {
                Caption = 'Receipts';
                ToolTip = 'Shows the employer''s unposted receipts.';
                Image = CashReceiptJournal;
                RunObject = page "PEN Receipts";
                RunPageLink = "Employer No." = field("No.");
            }
            action(PostedReceipts)
            {
                Caption = 'Posted Receipts';
                ToolTip = 'Shows the employer''s posted receipts.';
                Image = PostedReceipts;
                RunObject = page "PEN Posted Receipts";
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
        area(Reporting)
        {
            action(EmployerStatement)
            {
                Caption = 'Employer Statement';
                ToolTip = 'Prints the standard customer statement for this employer.';
                Image = Report;

                trigger OnAction()
                var
                    Customer: Record Customer;
                begin
                    Customer.SetRange("No.", Rec."No.");
                    Report.Run(Report::"Customer Statement", true, false, Customer);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Navigate)
            {
                Caption = 'Employer';
                actionref(Members_Promoted; Members) { }
                actionref(Batches_Promoted; Batches) { }
                actionref(Receipts_Promoted; Receipts) { }
                actionref(LedgerEntries_Promoted; LedgerEntries) { }
                actionref(EmployerStatement_Promoted; EmployerStatement) { }
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Rec."PEN Pension Employer" := true;
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.PENInitNewEmployer();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if Rec."No." = '' then
            exit(true);
        if (Rec.Name <> '') and (Rec."PEN Scheme Code" <> '') and (Rec."PEN KRA PIN" <> '') then
            exit(true);
        exit(Confirm(IncompleteEmployerQst, false, Rec."No."));
    end;

    var
        IncompleteEmployerQst: Label 'Employer %1 is missing a required field (Name, Scheme Code or KRA PIN). It cannot take members or contributions until it is complete.\\Close the page anyway?', Comment = '%1 = employer no.';
}
