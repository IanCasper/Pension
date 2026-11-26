namespace Zamara.Pension;

enum 50105 "PEN Batch Status"
{
    Caption = 'Batch Status';
    Extensible = false;

    value(0; Received) { Caption = 'Received'; }
    value(1; "In Progress") { Caption = 'In Progress'; }
    value(2; Posted) { Caption = 'Posted'; }
    value(3; "Completed with Errors") { Caption = 'Completed with Errors'; }
}
