namespace Zamara.Pension;

/// <summary>
/// Parsed line of an incoming contribution file before it is accepted. Temporary only.
/// Every intake route (JSON, CSV, API, generator) fills this buffer and hands it to
/// "PEN Contribution Intake".ReceiveBatch.
/// </summary>
table 50108 "PEN Intake Line Buffer"
{
    Caption = 'Intake Line Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Line No."; Integer) { Caption = 'Line No.'; }
        field(2; "Member No."; Code[20]) { Caption = 'Member No.'; }
        field(3; "Employee Amount"; Decimal) { Caption = 'Employee Amount'; AutoFormatType = 1; }
        field(4; "Employer Amount"; Decimal) { Caption = 'Employer Amount'; AutoFormatType = 1; }
        field(5; "Source Line No."; Integer) { Caption = 'Source Line No.'; }
    }

    keys
    {
        key(PK; "Line No.") { Clustered = true; }
    }
}
