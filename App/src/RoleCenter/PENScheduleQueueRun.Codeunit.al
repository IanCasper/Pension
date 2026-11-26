namespace Zamara.Pension;

/// <summary>
/// Entry point for the "Process Queue in Background" action on the role center and its cues:
/// creates a one-off Job Queue entry, so processing runs in a background session.
/// </summary>
codeunit 50109 "PEN Schedule Queue Run"
{
    trigger OnRun()
    var
        PensionMgt: Codeunit "PEN Pension Mgt";
    begin
        PensionMgt.CreateJobQueueEntry(false);
        Message(BackgroundStartedMsg);
    end;

    var
        BackgroundStartedMsg: Label 'Processing has been scheduled in the background. Check the Queue Monitor for progress.';
}
