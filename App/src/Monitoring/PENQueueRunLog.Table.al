namespace Zamara.Pension;

/// <summary>
/// One row per run of the queue processor: who ran, how long it took and what it did.
/// </summary>
table 50110 "PEN Queue Run Log"
{
    Caption = 'Queue Run Log';
    DataClassification = SystemMetadata;
    DrillDownPageId = "PEN Queue Run Log";
    LookupPageId = "PEN Queue Run Log";

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; AutoIncrement = true; }
        field(2; "Session ID"; Integer) { Caption = 'Session ID'; }
        field(3; "Server Instance ID"; Integer) { Caption = 'Server Instance ID'; }
        field(4; "Started At"; DateTime) { Caption = 'Started At'; }
        field(5; "Finished At"; DateTime) { Caption = 'Finished At'; }
        field(6; "Duration (ms)"; BigInteger) { Caption = 'Duration (ms)'; }
        field(7; Chunks; Integer) { Caption = 'Chunks'; }
        field(8; "Batch Size"; Integer) { Caption = 'Batch Size'; }
        field(9; "Lines Claimed"; Integer) { Caption = 'Lines Claimed'; }
        field(10; "Lines Posted"; Integer) { Caption = 'Lines Posted'; }
        field(11; "Lines Failed"; Integer) { Caption = 'Lines Failed'; }
        field(12; "Lines Dead Letter"; Integer) { Caption = 'Lines Dead Letter'; }
        field(13; "Lines Reset"; Integer) { Caption = 'Stale/Retry Lines Reset'; }
        field(14; "Batch Filter"; Code[20]) { Caption = 'Batch Filter'; }
        field(15; "User ID"; Code[50]) { Caption = 'User ID'; DataClassification = EndUserIdentifiableInformation; }
        field(16; "Lines per Second"; Decimal) { Caption = 'Lines per Second'; DecimalPlaces = 0 : 1; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Started; "Started At") { }
    }
}
