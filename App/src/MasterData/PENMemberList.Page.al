namespace Zamara.Pension;

page 50104 "PEN Member List"
{
    Caption = 'Pension Members';
    PageType = List;
    SourceTable = "PEN Member";
    CardPageId = "PEN Member Card";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ToolTip = 'Specifies the member number.'; }
                field("Full Name"; Rec."Full Name") { ToolTip = 'Specifies the member''s full name.'; }
                field("National ID No."; Rec."National ID No.") { ToolTip = 'Specifies the member''s national ID number.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the member''s employer.'; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field("Scheme Code"; Rec."Scheme Code") { ToolTip = 'Specifies the scheme, inherited from the employer.'; }
                field("Date Joined"; Rec."Date Joined") { ToolTip = 'Specifies the date the member joined the scheme.'; }
                field("Pensionable Salary"; Rec."Pensionable Salary") { ToolTip = 'Specifies the monthly pensionable salary.'; }
                field(Status; Rec.Status) { ToolTip = 'Specifies whether the member is active, exited or deceased.'; }
                field(Balance; Rec.Balance) { ToolTip = 'Specifies the member''s accumulated contributions. Choose the amount to see the ledger entries.'; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(LedgerEntries)
            {
                Caption = 'Ledger Entries';
                ToolTip = 'Shows the member''s ledger entries.';
                Image = LedgerEntries;
                RunObject = page "PEN Member Ledger Entries";
                RunPageLink = "Member No." = field("No.");
                RunPageView = sorting("Member No.", "Posting Date");
                ShortcutKey = 'Ctrl+F7';
            }
        }
        area(Reporting)
        {
            action(Statement)
            {
                Caption = 'Member Statement';
                ToolTip = 'Prints a statement for the selected members over a date range.';
                Image = Report;

                trigger OnAction()
                var
                    Member: Record "PEN Member";
                begin
                    CurrPage.SetSelectionFilter(Member);
                    Report.Run(Report::"PEN Member Statement", true, false, Member);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Report)
            {
                Caption = 'Report';
                actionref(Statement_Promoted; Statement) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Member';
                actionref(LedgerEntries_Promoted; LedgerEntries) { }
            }
        }
    }
}
