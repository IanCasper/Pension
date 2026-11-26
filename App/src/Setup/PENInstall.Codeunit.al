namespace Zamara.Pension;

codeunit 50106 "PEN Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        PensionSetup: Record "PEN Pension Setup";
    begin
        // Creates the setup record with its defaults (due day 9, batch size 500, 3 retries).
        PensionSetup.GetSetup();
    end;
}
