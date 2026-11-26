namespace Zamara.Pension;

using Microsoft.Foundation.NoSeries;
using Microsoft.Sales.Customer;

/// <summary>
/// Employers are standard customers. This extension adds the pension fields and rules the brief
/// specifies for "PEN Employer", so the employer's debt lives in the standard customer ledger.
/// </summary>
tableextension 50100 "PEN Customer" extends Customer
{
    fields
    {
        field(50100; "PEN Pension Employer"; Boolean)
        {
            Caption = 'Pension Employer';
            DataClassification = CustomerContent;
        }
        field(50101; "PEN Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
            DataClassification = CustomerContent;
            TableRelation = "PEN Scheme";

            trigger OnValidate()
            var
                Scheme: Record "PEN Scheme";
            begin
                if "PEN Scheme Code" = '' then
                    exit;
                Scheme.Get("PEN Scheme Code");
                if Scheme.Blocked then
                    Error(SchemeBlockedErr, Scheme.Code);
                Scheme.TestField("Customer Posting Group");
                Validate("Customer Posting Group", Scheme."Customer Posting Group");
            end;
        }
        field(50102; "PEN KRA PIN"; Code[20])
        {
            Caption = 'KRA PIN';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if "PEN KRA PIN" = '' then
                    exit;
                PENCheckKRAPINFormat("PEN KRA PIN");
                PENCheckKRAPINUnique();
            end;
        }
        field(50103; "PEN Employer Status"; Enum "PEN Employer Status")
        {
            Caption = 'Employer Status';
            DataClassification = CustomerContent;
        }
        field(50104; "PEN Member Count"; Integer)
        {
            Caption = 'Active Members';
            FieldClass = FlowField;
            CalcFormula = count("PEN Member" where("Employer No." = field("No."), Status = const(Active)));
            Editable = false;
        }
    }

    keys
    {
        key(PENKRAPIN; "PEN KRA PIN") { }
        key(PENEmployer; "PEN Pension Employer", "PEN Scheme Code") { }
    }

    var
        SchemeBlockedErr: Label 'Scheme %1 is blocked.', Comment = '%1 = scheme code';
        KRAPINFormatErr: Label 'KRA PIN %1 is not valid. The format is a letter, nine digits and a letter, for example A000000000Z.', Comment = '%1 = KRA PIN';
        KRAPINDuplicateErr: Label 'KRA PIN %1 is already used by employer %2.', Comment = '%1 = KRA PIN, %2 = customer no.';
        NotPensionEmployerErr: Label 'Customer %1 is not a pension employer.', Comment = '%1 = customer no.';
        EmployerSuspendedErr: Label 'Employer %1 is suspended and cannot take new members or contributions.', Comment = '%1 = customer no.';

    /// <summary>
    /// Marks a new customer as a pension employer and numbers it from Pension Setup "Employer Nos.".
    /// </summary>
    procedure PENInitNewEmployer()
    var
        PensionSetup: Record "PEN Pension Setup";
        NoSeries: Codeunit "No. Series";
    begin
        "PEN Pension Employer" := true;
        if "No." <> '' then
            exit;
        PensionSetup.GetSetup();
        PensionSetup.TestField("Employer Nos.");
        "No. Series" := PensionSetup."Employer Nos.";
        "No." := NoSeries.GetNextNo("No. Series");
    end;

    /// <summary>
    /// The brief's required fields for an employer.
    /// </summary>
    procedure PENCheckMandatoryFields()
    begin
        TestField(Name);
        TestField("PEN Scheme Code");
        TestField("PEN KRA PIN");
    end;

    /// <summary>
    /// An employer can take new members only when it is a complete, active pension employer on an unblocked scheme.
    /// </summary>
    procedure PENCheckCanAcceptMembers()
    var
        Scheme: Record "PEN Scheme";
    begin
        if not "PEN Pension Employer" then
            Error(NotPensionEmployerErr, "No.");
        PENCheckMandatoryFields();
        if "PEN Employer Status" <> "PEN Employer Status"::Active then
            Error(EmployerSuspendedErr, "No.");
        Scheme.Get("PEN Scheme Code");
        if Scheme.Blocked then
            Error(SchemeBlockedErr, Scheme.Code);
    end;

    local procedure PENCheckKRAPINFormat(PIN: Code[20])
    var
        Letters: Text;
        Digits: Text;
    begin
        Letters := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        Digits := '0123456789';
        if StrLen(PIN) <> 11 then
            Error(KRAPINFormatErr, PIN);
        if (DelChr(CopyStr(PIN, 1, 1), '=', Letters) <> '') or
           (DelChr(CopyStr(PIN, 11, 1), '=', Letters) <> '') or
           (DelChr(CopyStr(PIN, 2, 9), '=', Digits) <> '')
        then
            Error(KRAPINFormatErr, PIN);
    end;

    local procedure PENCheckKRAPINUnique()
    var
        OtherCustomer: Record Customer;
    begin
        OtherCustomer.SetCurrentKey("PEN KRA PIN");
        OtherCustomer.SetRange("PEN KRA PIN", "PEN KRA PIN");
        OtherCustomer.SetFilter("No.", '<>%1', "No.");
        OtherCustomer.SetLoadFields("No.");
        if OtherCustomer.FindFirst() then
            Error(KRAPINDuplicateErr, "PEN KRA PIN", OtherCustomer."No.");
    end;
}
