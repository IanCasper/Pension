namespace Zamara.Pension;

enum 50100 "PEN Scheme Type"
{
    Caption = 'Scheme Type';
    Extensible = true;

    value(0; "Defined Contribution") { Caption = 'Defined Contribution'; }
    value(1; Umbrella) { Caption = 'Umbrella'; }
}
