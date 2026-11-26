namespace Zamara.Pension;

table 50114 "PEN Posted Receipt Line"
{
    Caption = 'Posted Pension Receipt Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Receipt No."; Code[20]) { Caption = 'Receipt No.'; TableRelation = "PEN Posted Receipt Header"; }
        field(2; "Line No."; Integer) { Caption = 'Line No.'; }
        field(3; "Employer No."; Code[20]) { Caption = 'Employer No.'; }
        field(4; "Batch No."; Code[20]) { Caption = 'Batch No.'; TableRelation = "PEN Contribution Batch"; }
        field(5; Description; Text[100]) { Caption = 'Description'; }
        field(6; "Outstanding Amount"; Decimal) { Caption = 'Outstanding Before Receipt'; AutoFormatType = 1; }
        field(7; Amount; Decimal) { Caption = 'Amount'; AutoFormatType = 1; }
    }

    keys
    {
        key(PK; "Receipt No.", "Line No.") { Clustered = true; }
        key(Batch; "Batch No.") { }
    }
}
