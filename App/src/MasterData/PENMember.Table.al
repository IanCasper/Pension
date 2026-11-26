namespace Zamara.Pension;

using Microsoft.Foundation.NoSeries;
using Microsoft.Sales.Customer;

table 50103 "PEN Member"
{
    Caption = 'Pension Member';
    DataClassification = CustomerContent;
    DrillDownPageId = "PEN Member List";
    LookupPageId = "PEN Member List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';

            trigger OnValidate()
            var
                NoSeries: Codeunit "No. Series";
            begin
                if "No." <> xRec."No." then begin
                    GetPensionSetup();
                    NoSeries.TestManual(PensionSetup."Member Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; "First Name"; Text[50])
        {
            Caption = 'First Name';

            trigger OnValidate()
            begin
                UpdateFullName();
            end;
        }
        field(3; "Last Name"; Text[50])
        {
            Caption = 'Last Name';

            trigger OnValidate()
            begin
                UpdateFullName();
            end;
        }
        field(4; "Full Name"; Text[101])
        {
            Caption = 'Full Name';
            Editable = false;
        }
        field(5; "National ID No."; Code[20])
        {
            Caption = 'National ID No.';

            trigger OnValidate()
            begin
                CheckNationalIDUnique();
            end;
        }
        field(6; "Date of Birth"; Date)
        {
            Caption = 'Date of Birth';

            trigger OnValidate()
            begin
                CheckAgeAtJoining();
            end;
        }
        field(7; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            TableRelation = Customer where("PEN Pension Employer" = const(true));

            trigger OnValidate()
            var
                Employer: Record Customer;
            begin
                if "Employer No." = '' then begin
                    "Scheme Code" := '';
                    exit;
                end;
                Employer.Get("Employer No.");
                Employer.PENCheckCanAcceptMembers();
                "Scheme Code" := Employer."PEN Scheme Code";
            end;
        }
        field(8; "Employer Name"; Text[100])
        {
            Caption = 'Employer Name';
            FieldClass = FlowField;
            CalcFormula = lookup(Customer.Name where("No." = field("Employer No.")));
            Editable = false;
        }
        field(9; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
            TableRelation = "PEN Scheme";
            Editable = false;
        }
        field(10; "Date Joined"; Date)
        {
            Caption = 'Date Joined';

            trigger OnValidate()
            begin
                CheckAgeAtJoining();
            end;
        }
        field(11; "Pensionable Salary"; Decimal)
        {
            Caption = 'Pensionable Salary';
            AutoFormatType = 1;

            trigger OnValidate()
            begin
                if "Pensionable Salary" <= 0 then
                    Error(SalaryMustBePositiveErr);
            end;
        }
        field(12; Status; Enum "PEN Member Status")
        {
            Caption = 'Status';
        }
        field(13; Balance; Decimal)
        {
            Caption = 'Balance';
            AutoFormatType = 1;
            FieldClass = FlowField;
            CalcFormula = sum("PEN Member Ledger Entry".Amount where("Member No." = field("No."), "Posting Date" = field("Date Filter")));
            Editable = false;
        }
        field(14; "Date Filter"; Date)
        {
            Caption = 'Date Filter';
            FieldClass = FlowFilter;
        }
        field(15; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            TableRelation = "No. Series";
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(NationalID; "National ID No.") { }
        key(Employer; "Employer No.", Status) { }
        key(Scheme; "Scheme Code", Status) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Full Name", "National ID No.", "Employer No.") { }
        fieldgroup(Brick; "No.", "Full Name", "Employer No.", Status) { }
    }

    trigger OnInsert()
    var
        Employer: Record Customer;
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            GetPensionSetup();
            PensionSetup.TestField("Member Nos.");
            "No. Series" := PensionSetup."Member Nos.";
            "No." := NoSeries.GetNextNo("No. Series");
        end;
        // Records created by code may set the employer without validating it; the rule still applies.
        if "Employer No." <> '' then begin
            Employer.Get("Employer No.");
            Employer.PENCheckCanAcceptMembers();
            "Scheme Code" := Employer."PEN Scheme Code";
        end;
        if "National ID No." <> '' then
            CheckNationalIDUnique();
    end;

    trigger OnDelete()
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
    begin
        MemberLedgerEntry.SetRange("Member No.", "No.");
        if not MemberLedgerEntry.IsEmpty() then
            Error(MemberHasEntriesErr, "No.");
    end;

    var
        PensionSetup: Record "PEN Pension Setup";
        PensionSetupRead: Boolean;
        SalaryMustBePositiveErr: Label 'Pensionable Salary must be greater than zero.';
        NationalIDDuplicateErr: Label 'National ID No. %1 is already registered to member %2.', Comment = '%1 = national ID, %2 = member no.';
        AgeAtJoiningErr: Label 'The member must be between %1 and %2 years old on the date joined. On %3 the member is %4.', Comment = '%1 = min age, %2 = max age, %3 = date joined, %4 = age';
        MemberHasEntriesErr: Label 'Member %1 has ledger entries and cannot be deleted. Set the status to Exited instead.', Comment = '%1 = member no.';

    /// <summary>
    /// The brief's required fields for a member.
    /// </summary>
    procedure CheckMandatoryFields()
    begin
        TestField("First Name");
        TestField("Last Name");
        TestField("National ID No.");
        TestField("Date of Birth");
        TestField("Employer No.");
        TestField("Date Joined");
        if "Pensionable Salary" <= 0 then
            Error(SalaryMustBePositiveErr);
    end;

    procedure AssistEdit(OldMember: Record "PEN Member"): Boolean
    var
        Member: Record "PEN Member";
        NoSeries: Codeunit "No. Series";
    begin
        Member := Rec;
        GetPensionSetup();
        PensionSetup.TestField("Member Nos.");
        if NoSeries.LookupRelatedNoSeries(PensionSetup."Member Nos.", OldMember."No. Series", Member."No. Series") then begin
            Member."No." := NoSeries.GetNextNo(Member."No. Series");
            Rec := Member;
            exit(true);
        end;
    end;

    /// <summary>
    /// Age in whole years on a given date.
    /// </summary>
    procedure AgeOn(OnDate: Date): Integer
    var
        Age: Integer;
    begin
        Age := Date2DMY(OnDate, 3) - Date2DMY("Date of Birth", 3);
        if (Date2DMY(OnDate, 2) < Date2DMY("Date of Birth", 2)) or
           ((Date2DMY(OnDate, 2) = Date2DMY("Date of Birth", 2)) and (Date2DMY(OnDate, 1) < Date2DMY("Date of Birth", 1)))
        then
            Age -= 1;
        exit(Age);
    end;

    local procedure CheckAgeAtJoining()
    var
        Age: Integer;
    begin
        if ("Date of Birth" = 0D) or ("Date Joined" = 0D) then
            exit;
        Age := AgeOn("Date Joined");
        if (Age < MinJoiningAge()) or (Age > MaxJoiningAge()) then
            Error(AgeAtJoiningErr, MinJoiningAge(), MaxJoiningAge(), "Date Joined", Age);
    end;

    local procedure CheckNationalIDUnique()
    var
        OtherMember: Record "PEN Member";
    begin
        if "National ID No." = '' then
            exit;
        OtherMember.SetCurrentKey("National ID No.");
        OtherMember.SetRange("National ID No.", "National ID No.");
        OtherMember.SetFilter("No.", '<>%1', "No.");
        OtherMember.SetLoadFields("No.");
        if OtherMember.FindFirst() then
            Error(NationalIDDuplicateErr, "National ID No.", OtherMember."No.");
    end;

    local procedure UpdateFullName()
    begin
        "Full Name" := CopyStr(DelChr("First Name" + ' ' + "Last Name", '<>', ' '), 1, MaxStrLen("Full Name"));
    end;

    local procedure GetPensionSetup()
    begin
        if PensionSetupRead then
            exit;
        PensionSetup.GetSetup();
        PensionSetupRead := true;
    end;

    local procedure MinJoiningAge(): Integer
    begin
        exit(18);
    end;

    local procedure MaxJoiningAge(): Integer
    begin
        exit(65);
    end;
}
