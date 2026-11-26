namespace Zamara.Pension;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Sales.Customer;

table 50101 "PEN Scheme"
{
    Caption = 'Pension Scheme';
    DataClassification = CustomerContent;
    DrillDownPageId = "PEN Schemes";
    LookupPageId = "PEN Schemes";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; "Scheme Type"; Enum "PEN Scheme Type")
        {
            Caption = 'Scheme Type';
        }
        field(4; "Employer Cap %"; Decimal)
        {
            Caption = 'Employer Cap %';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;
        }
        field(5; "Customer Posting Group"; Code[20])
        {
            Caption = 'Customer Posting Group';
            TableRelation = "Customer Posting Group";

            trigger OnValidate()
            var
                CustomerPostingGroup: Record "Customer Posting Group";
            begin
                if "Customer Posting Group" = '' then begin
                    "Contribution Receivable Acc." := '';
                    exit;
                end;
                CustomerPostingGroup.Get("Customer Posting Group");
                CustomerPostingGroup.TestField("Receivables Account");
                CheckGLAccount(CustomerPostingGroup."Receivables Account");
                "Contribution Receivable Acc." := CustomerPostingGroup."Receivables Account";
            end;
        }
        field(6; "Contribution Receivable Acc."; Code[20])
        {
            Caption = 'Contribution Receivable Acc.';
            TableRelation = "G/L Account";
            Editable = false;
        }
        field(7; "Member Liability Acc."; Code[20])
        {
            Caption = 'Member Liability Acc.';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));

            trigger OnValidate()
            begin
                CheckGLAccount("Member Liability Acc.");
            end;
        }
        field(8; "Penalty Income Acc."; Code[20])
        {
            Caption = 'Penalty Income Acc.';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));

            trigger OnValidate()
            begin
                CheckGLAccount("Penalty Income Acc.");
            end;
        }
        field(9; Blocked; Boolean)
        {
            Caption = 'Blocked';
        }
        field(20; "No. of Employers"; Integer)
        {
            Caption = 'No. of Employers';
            FieldClass = FlowField;
            CalcFormula = count(Customer where("PEN Pension Employer" = const(true), "PEN Scheme Code" = field(Code)));
            Editable = false;
        }
        field(21; "No. of Active Members"; Integer)
        {
            Caption = 'No. of Active Members';
            FieldClass = FlowField;
            CalcFormula = count("PEN Member" where("Scheme Code" = field(Code), Status = const(Active)));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Code", Description, "Scheme Type") { }
    }

    trigger OnInsert()
    begin
        TestField(Description);
    end;

    trigger OnModify()
    begin
        TestField(Description);
    end;

    trigger OnDelete()
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("PEN Pension Employer", true);
        Customer.SetRange("PEN Scheme Code", Code);
        if not Customer.IsEmpty() then
            Error(SchemeInUseErr, Code);
    end;

    var
        SchemeInUseErr: Label 'Scheme %1 cannot be deleted because employers are attached to it. Block it instead.', Comment = '%1 = scheme code';
        AccountNotPostingErr: Label 'G/L account %1 must be a posting account that is not blocked.', Comment = '%1 = G/L account no.';

    /// <summary>
    /// Checks that the scheme has every account it needs before anything is posted against it.
    /// </summary>
    procedure CheckPostingSetup()
    begin
        TestField("Customer Posting Group");
        TestField("Contribution Receivable Acc.");
        TestField("Member Liability Acc.");
        TestField("Penalty Income Acc.");
    end;

    local procedure CheckGLAccount(AccountNo: Code[20])
    var
        GLAccount: Record "G/L Account";
    begin
        if AccountNo = '' then
            exit;
        GLAccount.Get(AccountNo);
        if (GLAccount."Account Type" <> GLAccount."Account Type"::Posting) or GLAccount.Blocked then
            Error(AccountNotPostingErr, AccountNo);
    end;
}
