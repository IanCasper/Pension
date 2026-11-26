namespace Zamara.Pension;

/// <summary>
/// One contribution batch submitted through the API page. Keeps the raw payload for audit.
/// </summary>
table 50109 "PEN API Intake Request"
{
    Caption = 'API Intake Request';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; AutoIncrement = true; }
        field(2; "Message ID"; Text[100]) { Caption = 'Message ID'; }
        field(3; "Batch No."; Code[20]) { Caption = 'Batch No.'; TableRelation = "PEN Contribution Batch"; }
        field(4; "No. of Lines"; Integer) { Caption = 'No. of Lines'; }
        field(5; "Received At"; DateTime) { Caption = 'Received At'; }
        field(6; "Received By"; Code[50]) { Caption = 'Received By'; DataClassification = EndUserIdentifiableInformation; }
        field(7; Payload; Blob) { Caption = 'Payload'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }
}
