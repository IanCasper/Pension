namespace Zamara.Pension;

/// <summary>
/// Entry point for the "Import Contribution File" action on the role center and its cues.
/// </summary>
codeunit 50108 "PEN Import Contribution File"
{
    trigger OnRun()
    var
        ContributionIntake: Codeunit "PEN Contribution Intake";
    begin
        ContributionIntake.ImportFromFile();
    end;
}
