namespace Zamara.Pension;

page 50105 "PEN Member Card"
{
    Caption = 'Pension Member';
    PageType = Card;
    SourceTable = "PEN Member";
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
                    ToolTip = 'Specifies the member number.';

                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field("First Name"; Rec."First Name") { ToolTip = 'Specifies the member''s first name.'; ShowMandatory = true; }
                field("Last Name"; Rec."Last Name") { ToolTip = 'Specifies the member''s last name.'; ShowMandatory = true; }
                field("Full Name"; Rec."Full Name") { ToolTip = 'Specifies the member''s full name.'; }
                field("National ID No."; Rec."National ID No.") { ToolTip = 'Specifies the member''s national ID number. It must be unique.'; ShowMandatory = true; }
                field("Date of Birth"; Rec."Date of Birth") { ToolTip = 'Specifies the member''s date of birth. The member must be 18 to 65 years old on the date joined.'; ShowMandatory = true; }
                field(Status; Rec.Status) { ToolTip = 'Specifies whether the member is active, exited or deceased. Only active members receive contributions.'; }
            }
            group(Employment)
            {
                Caption = 'Employment';
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the member''s employer. The member joins the employer''s scheme.'; ShowMandatory = true; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field("Scheme Code"; Rec."Scheme Code") { ToolTip = 'Specifies the scheme, inherited from the employer.'; }
                field("Date Joined"; Rec."Date Joined") { ToolTip = 'Specifies the date the member joined the scheme.'; ShowMandatory = true; }
                field("Pensionable Salary"; Rec."Pensionable Salary") { ToolTip = 'Specifies the monthly pensionable salary. It must be greater than zero.'; ShowMandatory = true; }
            }
            group(Contributions)
            {
                Caption = 'Contributions';
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
            action(QueueLines)
            {
                Caption = 'Contribution Lines';
                ToolTip = 'Shows every contribution line received for this member, with its processing status.';
                Image = List;
                RunObject = page "PEN Contribution Queue";
                RunPageLink = "Member No." = field("No.");
            }
        }
        area(Reporting)
        {
            action(Statement)
            {
                Caption = 'Member Statement';
                ToolTip = 'Prints a statement for this member over a date range.';
                Image = Report;

                trigger OnAction()
                var
                    Member: Record "PEN Member";
                begin
                    Member.SetRange("No.", Rec."No.");
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
                actionref(QueueLines_Promoted; QueueLines) { }
            }
        }
    }

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if Rec."No." = '' then
            exit(true);
        if IsComplete() then
            exit(true);
        exit(Confirm(IncompleteMemberQst, false, Rec."No."));
    end;

    var
        IncompleteMemberQst: Label 'Member %1 is missing a required field (name, National ID, date of birth, employer, date joined or pensionable salary). Contributions for the member will fail until it is complete.\\Close the page anyway?', Comment = '%1 = member no.';

    local procedure IsComplete(): Boolean
    begin
        exit((Rec."First Name" <> '') and (Rec."Last Name" <> '') and (Rec."National ID No." <> '') and
             (Rec."Date of Birth" <> 0D) and (Rec."Employer No." <> '') and (Rec."Date Joined" <> 0D) and
             (Rec."Pensionable Salary" > 0));
    end;
}
