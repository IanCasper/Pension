namespace Zamara.Pension;

using Microsoft.Sales.Customer;

pageextension 50100 "PEN Customer Card" extends "Customer Card"
{
    layout
    {
        addlast(content)
        {
            group(PENPension)
            {
                Caption = 'Pension';
                Visible = PENIsPensionEmployer;
                field("PEN Scheme Code"; Rec."PEN Scheme Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the pension scheme the employer belongs to.';
                }
                field("PEN KRA PIN"; Rec."PEN KRA PIN")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the employer''s KRA PIN.';
                }
                field("PEN Employer Status"; Rec."PEN Employer Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the pension employer is active or suspended.';
                }
                field("PEN Member Count"; Rec."PEN Member Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of active members.';
                }
            }
        }
    }

    actions
    {
        addlast(navigation)
        {
            action(PENOpenEmployerCard)
            {
                ApplicationArea = All;
                Caption = 'Pension Employer Card';
                ToolTip = 'Opens this customer on the Pension Employer card.';
                Image = Customer;
                Visible = PENIsPensionEmployer;
                RunObject = page "PEN Employer Card";
                RunPageLink = "No." = field("No.");
            }
            action(PENMembers)
            {
                ApplicationArea = All;
                Caption = 'Pension Members';
                ToolTip = 'Shows the pension members employed by this customer.';
                Image = Employee;
                Visible = PENIsPensionEmployer;
                RunObject = page "PEN Member List";
                RunPageLink = "Employer No." = field("No.");
            }
            action(PENContributionBatches)
            {
                ApplicationArea = All;
                Caption = 'Contribution Batches';
                ToolTip = 'Shows the contribution batches received from this employer.';
                Image = Documents;
                Visible = PENIsPensionEmployer;
                RunObject = page "PEN Contribution Batches";
                RunPageLink = "Employer No." = field("No.");
            }
            action(PENReceipts)
            {
                ApplicationArea = All;
                Caption = 'Pension Receipts';
                ToolTip = 'Shows the unposted pension receipts for this employer.';
                Image = CashReceiptJournal;
                Visible = PENIsPensionEmployer;
                RunObject = page "PEN Receipts";
                RunPageLink = "Employer No." = field("No.");
            }
        }
        // A tab of its own in the action bar, so the pension actions are not buried under Related.
        addlast(Promoted)
        {
            group(PENCategory_Pension)
            {
                Caption = 'Pension';
                actionref(PENOpenEmployerCard_Promoted; PENOpenEmployerCard) { }
                actionref(PENMembers_Promoted; PENMembers) { }
                actionref(PENContributionBatches_Promoted; PENContributionBatches) { }
                actionref(PENReceipts_Promoted; PENReceipts) { }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        PENIsPensionEmployer := Rec."PEN Pension Employer";
    end;

    var
        PENIsPensionEmployer: Boolean;
}
