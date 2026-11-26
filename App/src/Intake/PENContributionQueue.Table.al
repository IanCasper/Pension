namespace Zamara.Pension;

using Microsoft.Sales.Customer;

/// <summary>
/// One member line of a received contribution batch, and its processing state.
/// </summary>
table 50105 "PEN Contribution Queue"
{
    Caption = 'Contribution Queue';
    DataClassification = CustomerContent;
    DrillDownPageId = "PEN Contribution Queue";
    LookupPageId = "PEN Contribution Queue";

    fields
    {
        field(1; "Batch No."; Code[20])
        {
            Caption = 'Batch No.';
            TableRelation = "PEN Contribution Batch";
            Editable = false;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            Editable = false;
        }
        field(3; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            TableRelation = Customer;
            ValidateTableRelation = false;
            Editable = false;
        }
        field(4; "Member No."; Code[20])
        {
            Caption = 'Member No.';
            TableRelation = "PEN Member";
            ValidateTableRelation = false;
            Editable = false;
        }
        field(5; Period; Code[7])
        {
            Caption = 'Period';
            Editable = false;
        }
        field(6; "Employee Amount"; Decimal)
        {
            Caption = 'Employee Amount';
            AutoFormatType = 1;
            Editable = false;
        }
        field(7; "Employer Amount"; Decimal)
        {
            Caption = 'Employer Amount';
            AutoFormatType = 1;
            Editable = false;
        }
        field(8; "Line Amount"; Decimal)
        {
            Caption = 'Line Amount';
            AutoFormatType = 1;
            Editable = false;
        }
        field(9; Status; Enum "PEN Queue Status")
        {
            Caption = 'Status';
            Editable = false;
        }
        field(10; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            Editable = false;
        }
        field(11; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
            Editable = false;
        }
        field(12; "Last Attempt At"; DateTime)
        {
            Caption = 'Last Attempt At';
            Editable = false;
        }
        field(13; "Claimed By Session ID"; Integer)
        {
            Caption = 'Claimed By Session ID';
            Editable = false;
        }
        field(14; "Claimed By Server Inst. ID"; Integer)
        {
            Caption = 'Claimed By Server Instance ID';
            Editable = false;
        }
        field(15; "Claimed At"; DateTime)
        {
            Caption = 'Claimed At';
            Editable = false;
        }
        field(16; "Posted Document No."; Code[20])
        {
            Caption = 'Posted Document No.';
            Editable = false;
        }
        field(17; "Posted At"; DateTime)
        {
            Caption = 'Posted At';
            Editable = false;
        }
        field(18; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
            TableRelation = "PEN Scheme";
            ValidateTableRelation = false;
            Editable = false;
        }
        field(19; "Member Name"; Text[101])
        {
            Caption = 'Member Name';
            FieldClass = FlowField;
            CalcFormula = lookup("PEN Member"."Full Name" where("No." = field("Member No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Batch No.", "Line No.")
        {
            Clustered = true;
        }
        // Claiming: WHERE Status = Pending ORDER BY Batch No., Line No.
        key(Status; Status, "Batch No.", "Line No.") { }
        // Duplicate check: is there a Posted line for this member and period?
        key(MemberPeriod; "Member No.", Period, Status) { }
        // Batch FlowFields: counts and amounts by batch and status.
        key(BatchStatus; "Batch No.", Status)
        {
            SumIndexFields = "Line Amount";
        }
    }
}
