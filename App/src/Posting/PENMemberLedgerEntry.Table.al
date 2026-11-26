namespace Zamara.Pension;

using Microsoft.Sales.Customer;

/// <summary>
/// Member sub-ledger. Two entries per posted contribution line (employee and employer share).
/// </summary>
table 50106 "PEN Member Ledger Entry"
{
    Caption = 'Member Ledger Entry';
    DataClassification = CustomerContent;
    DrillDownPageId = "PEN Member Ledger Entries";
    LookupPageId = "PEN Member Ledger Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            // SQL identity: unique even when two sessions post at the same time, with no FindLast + 1 race or lock.
            AutoIncrement = true;
        }
        field(2; "Member No."; Code[20])
        {
            Caption = 'Member No.';
            TableRelation = "PEN Member";
        }
        field(3; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            TableRelation = Customer;
        }
        field(4; "Scheme Code"; Code[20])
        {
            Caption = 'Scheme Code';
            TableRelation = "PEN Scheme";
        }
        field(5; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(6; Period; Code[7])
        {
            Caption = 'Period';
        }
        field(7; "Entry Type"; Enum "PEN Ledger Entry Type")
        {
            Caption = 'Entry Type';
        }
        field(8; Amount; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
        }
        field(9; "Batch No."; Code[20])
        {
            Caption = 'Batch No.';
            TableRelation = "PEN Contribution Batch";
        }
        field(10; "Batch Line No."; Integer)
        {
            Caption = 'Batch Line No.';
        }
        field(11; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(12; "Posted By"; Code[50])
        {
            Caption = 'Posted By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(13; "Posted At"; DateTime)
        {
            Caption = 'Posted At';
        }
        field(14; "Member Name"; Text[101])
        {
            Caption = 'Member Name';
            FieldClass = FlowField;
            CalcFormula = lookup("PEN Member"."Full Name" where("No." = field("Member No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(MemberDate; "Member No.", "Posting Date")
        {
            SumIndexFields = Amount;
        }
        key(MemberPeriod; "Member No.", Period, "Entry Type") { }
        key(Batch; "Batch No.")
        {
            SumIndexFields = Amount;
        }
        key(Document; "Document No.", "Posting Date") { }
    }
}
