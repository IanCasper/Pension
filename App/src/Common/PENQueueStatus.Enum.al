namespace Zamara.Pension;

enum 50103 "PEN Queue Status"
{
    Caption = 'Queue Status';
    Extensible = false;

    value(0; Pending) { Caption = 'Pending'; }
    value(1; Processing) { Caption = 'Processing'; }
    value(2; Posted) { Caption = 'Posted'; }
    value(3; Failed) { Caption = 'Failed'; }
    value(4; "Dead Letter") { Caption = 'Dead Letter'; }
}
