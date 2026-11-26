namespace Zamara.Pension;

/// <summary>
/// One row per contribution period on a member statement. Temporary only.
/// </summary>
table 50107 "PEN Statement Buffer"
{
    Caption = 'Statement Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(2; Period; Code[7]) { Caption = 'Period'; }
        field(3; "Posting Date"; Date) { Caption = 'Posting Date'; }
        field(4; "Employee Amount"; Decimal) { Caption = 'Employee Amount'; AutoFormatType = 1; }
        field(5; "Employer Amount"; Decimal) { Caption = 'Employer Amount'; AutoFormatType = 1; }
        field(6; "Total Amount"; Decimal) { Caption = 'Total Amount'; AutoFormatType = 1; }
        field(7; "Running Balance"; Decimal) { Caption = 'Running Balance'; AutoFormatType = 1; }
        field(8; Description; Text[100]) { Caption = 'Description'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Date; "Posting Date", Period) { }
    }
}
