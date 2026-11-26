namespace Zamara.Pension;

page 50101 "PEN Schemes"
{
    Caption = 'Pension Schemes';
    PageType = List;
    SourceTable = "PEN Scheme";
    UsageCategory = Lists;
    ApplicationArea = All;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Code"; Rec."Code") { ToolTip = 'Specifies the scheme code.'; ShowMandatory = true; }
                field(Description; Rec.Description) { ToolTip = 'Specifies the scheme name.'; ShowMandatory = true; }
                field("Scheme Type"; Rec."Scheme Type") { ToolTip = 'Specifies whether this is a defined contribution or an umbrella scheme.'; }
                field("Employer Cap %"; Rec."Employer Cap %") { ToolTip = 'Specifies the maximum employer contribution as a percentage of pensionable salary. 0 means no cap.'; }
                field("Customer Posting Group"; Rec."Customer Posting Group") { ToolTip = 'Specifies the customer posting group given to this scheme''s employers. Its receivables account is the Contribution Receivable account.'; }
                field("Contribution Receivable Acc."; Rec."Contribution Receivable Acc.") { ToolTip = 'Specifies the G/L account debited when employers are invoiced. It comes from the customer posting group.'; }
                field("Member Liability Acc."; Rec."Member Liability Acc.") { ToolTip = 'Specifies the G/L account credited with members'' contributions.'; }
                field("Penalty Income Acc."; Rec."Penalty Income Acc.") { ToolTip = 'Specifies the G/L account credited with late remittance penalties.'; }
                field(Blocked; Rec.Blocked) { ToolTip = 'Specifies that no new members or contributions are accepted for this scheme.'; }
                field("No. of Employers"; Rec."No. of Employers") { ToolTip = 'Specifies how many employers belong to the scheme.'; }
                field("No. of Active Members"; Rec."No. of Active Members") { ToolTip = 'Specifies how many active members belong to the scheme.'; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Employers)
            {
                Caption = 'Employers';
                ToolTip = 'Shows the employers in this scheme.';
                Image = Customer;
                RunObject = page "PEN Employer List";
                RunPageLink = "PEN Scheme Code" = field(Code);
            }
            action(Members)
            {
                Caption = 'Members';
                ToolTip = 'Shows the members in this scheme.';
                Image = Employee;
                RunObject = page "PEN Member List";
                RunPageLink = "Scheme Code" = field(Code);
            }
        }
    }
}
