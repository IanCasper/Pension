namespace Zamara.Pension;

enum 50104 "PEN Ledger Entry Type"
{
    Caption = 'Ledger Entry Type';
    Extensible = true;

    value(0; "Employee Contribution") { Caption = 'Employee Contribution'; }
    value(1; "Employer Contribution") { Caption = 'Employer Contribution'; }
}
