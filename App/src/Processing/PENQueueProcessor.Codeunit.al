namespace Zamara.Pension;

using System.Environment;
using System.Threading;

/// <summary>
/// Job Queue codeunit that processes Pending contribution lines in chunks of "Queue Batch Size".
///
/// For each chunk:
///  1. Claim    - under a short lock on the Pension Setup row (a mutex), move up to N Pending lines
///                to Processing and stamp them with this session. Commit, which releases the lock.
///  2. Validate - read-only business rules. Failing lines are marked Failed or Dead Letter with their error. Commit.
///  3. Post     - Codeunit.Run on "PEN Contribution Post" for the valid lines. If posting raises an
///                error, the chunk rolls back and its lines are marked Failed. Commit.
/// Users keep working because every transaction is short, and no lock is held between chunks.
/// </summary>
codeunit 50101 "PEN Queue Processor"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    begin
        ProcessPending();
    end;

    var
        PensionSetup: Record "PEN Pension Setup";
        LineValidation: Codeunit "PEN Line Validation";
        PensionMgt: Codeunit "PEN Pension Mgt";
        BatchFilter: Code[20];
        RunFinishedTxt: Label 'Pension contribution queue run finished: %1 lines claimed, %2 posted, %3 failed, %4 dead letter in %5 ms.', Locked = true;
        ChunkFinishedTxt: Label 'Pension contribution chunk processed: %1 lines in %2 ms.', Locked = true;

    /// <summary>
    /// Restricts the next run to one batch. Used by the "Process Now" action on a batch and by the tests.
    /// </summary>
    procedure SetBatchFilter(NewBatchFilter: Code[20])
    begin
        BatchFilter := NewBatchFilter;
    end;

    /// <summary>
    /// Processes Pending lines until none are left. Returns the number of lines claimed.
    /// </summary>
    procedure ProcessPending(): Integer
    var
        RunLog: Record "PEN Queue Run Log";
        TempClaimedLine: Record "PEN Contribution Queue" temporary;
        TempValidLine: Record "PEN Contribution Queue" temporary;
        TouchedBatches: List of [Code[20]];
        ChunkStartedAt: DateTime;
    begin
        PensionSetup.GetSetup();
        LineValidation.ResetCache();
        StartRunLog(RunLog);
        RunLog."Lines Reset" := PrepareQueue();
        RunLog.Modify();
        Commit();

        while ClaimChunk(TempClaimedLine) do begin
            ChunkStartedAt := CurrentDateTime();
            RunLog.Chunks += 1;
            RunLog."Lines Claimed" += TempClaimedLine.Count();
            Clear(TouchedBatches);

            ValidateChunk(TempClaimedLine, TempValidLine, TouchedBatches, RunLog);
            Commit();

            PostChunk(TempValidLine, RunLog);
            Commit();

            PensionMgt.UpdateBatchStatuses(TouchedBatches);
            RunLog.Modify();
            Commit();

            LogChunkTelemetry(TempClaimedLine.Count(), CurrentDateTime() - ChunkStartedAt);
        end;

        FinishRunLog(RunLog);
        Commit();
        LogRunTelemetry(RunLog);
        exit(RunLog."Lines Claimed");
    end;

    /// <summary>
    /// Runs once at the start of a run, under the mutex:
    ///  - lines left in Processing by a session that no longer exists (a crashed run) go back to Pending;
    ///  - Failed lines go back to Pending for their retry. Lines that fail during this run wait for the next run.
    /// </summary>
    local procedure PrepareQueue() LinesReset: Integer
    var
        LockSetup: Record "PEN Pension Setup";
        QueueLine: Record "PEN Contribution Queue";
        StaleLine: Record "PEN Contribution Queue";
    begin
        LockSetup.LockTable();
        LockSetup.Get();

        QueueLine.SetCurrentKey(Status, "Batch No.", "Line No.");
        QueueLine.SetRange(Status, QueueLine.Status::Processing);
        ApplyBatchFilter(QueueLine);
        QueueLine.SetLoadFields("Batch No.", "Line No.", Status, "Claimed By Session ID", "Claimed By Server Inst. ID");
        if QueueLine.FindSet() then
            repeat
                if not IsClaimOwnerAlive(QueueLine) then begin
                    StaleLine.Get(QueueLine."Batch No.", QueueLine."Line No.");
                    StaleLine.Status := StaleLine.Status::Pending;
                    PensionMgt.ClearClaim(StaleLine);
                    StaleLine.Modify();
                    LinesReset += 1;
                end;
            until QueueLine.Next() = 0;

        QueueLine.Reset();
        QueueLine.SetCurrentKey(Status, "Batch No.", "Line No.");
        QueueLine.SetRange(Status, QueueLine.Status::Failed);
        ApplyBatchFilter(QueueLine);
        LinesReset += QueueLine.Count();
        QueueLine.ModifyAll(Status, QueueLine.Status::Pending);
    end;

    /// <summary>
    /// Claims up to "Queue Batch Size" Pending lines. The lock on the setup row serialises claiming
    /// between sessions, so two Job Queue entries can never claim the same line. The commit at the end
    /// makes the claim visible and releases the lock before any validation or posting work starts.
    /// </summary>
    local procedure ClaimChunk(var TempClaimedLine: Record "PEN Contribution Queue" temporary): Boolean
    var
        LockSetup: Record "PEN Pension Setup";
        QueueLine: Record "PEN Contribution Queue";
        ClaimLine: Record "PEN Contribution Queue";
        ClaimedAt: DateTime;
        Claimed: Integer;
    begin
        TempClaimedLine.Reset();
        TempClaimedLine.DeleteAll();

        LockSetup.LockTable();
        LockSetup.Get();

        QueueLine.SetCurrentKey(Status, "Batch No.", "Line No.");
        QueueLine.SetRange(Status, QueueLine.Status::Pending);
        ApplyBatchFilter(QueueLine);
        if QueueLine.FindSet() then
            repeat
                TempClaimedLine := QueueLine;
                TempClaimedLine.Insert();
                Claimed += 1;
            until (QueueLine.Next() = 0) or (Claimed >= PensionSetup."Queue Batch Size");

        if Claimed = 0 then begin
            Commit();
            exit(false);
        end;

        // Write the claim through a second record variable, so the loop above never modifies the key it is reading.
        ClaimedAt := CurrentDateTime();
        TempClaimedLine.FindSet();
        repeat
            ClaimLine.Get(TempClaimedLine."Batch No.", TempClaimedLine."Line No.");
            ClaimLine.Status := ClaimLine.Status::Processing;
            ClaimLine."Claimed By Session ID" := SessionId();
            ClaimLine."Claimed By Server Inst. ID" := ServiceInstanceId();
            ClaimLine."Claimed At" := ClaimedAt;
            ClaimLine."Last Attempt At" := ClaimedAt;
            ClaimLine.Modify();
            TempClaimedLine := ClaimLine;
            TempClaimedLine.Modify();
        until TempClaimedLine.Next() = 0;

        Commit();
        exit(true);
    end;

    local procedure ValidateChunk(var TempClaimedLine: Record "PEN Contribution Queue" temporary; var TempValidLine: Record "PEN Contribution Queue" temporary; var TouchedBatches: List of [Code[20]]; var RunLog: Record "PEN Queue Run Log")
    var
        ErrorText: Text;
    begin
        TempValidLine.Reset();
        TempValidLine.DeleteAll();

        TempClaimedLine.FindSet();
        repeat
            if not TouchedBatches.Contains(TempClaimedLine."Batch No.") then
                TouchedBatches.Add(TempClaimedLine."Batch No.");
            if LineValidation.ValidateLine(TempClaimedLine, ErrorText) then begin
                TempValidLine := TempClaimedLine;
                TempValidLine.Insert();
            end else
                FailLine(TempClaimedLine, ErrorText, RunLog);
        until TempClaimedLine.Next() = 0;
    end;

    local procedure PostChunk(var TempValidLine: Record "PEN Contribution Queue" temporary; var RunLog: Record "PEN Queue Run Log")
    var
        ContributionPost: Codeunit "PEN Contribution Post";
        ErrorText: Text;
    begin
        TempValidLine.Reset();
        if TempValidLine.IsEmpty() then
            exit;

        ClearLastError();
        if ContributionPost.Run(TempValidLine) then begin
            RunLog."Lines Posted" += ContributionPost.GetPostedCount();
            RunLog."Lines Failed" += ContributionPost.GetFailedCount();
            RunLog."Lines Dead Letter" += ContributionPost.GetDeadLetterCount();
            exit;
        end;

        // Posting failed and everything in the chunk was rolled back. Fail each valid line with the error,
        // so it is retried on the next run and ends in Dead Letter if the problem persists.
        ErrorText := GetLastErrorText();
        TempValidLine.FindSet();
        repeat
            LineValidation.ForgetLine(TempValidLine);
            FailLine(TempValidLine, ErrorText, RunLog);
        until TempValidLine.Next() = 0;
    end;

    local procedure FailLine(ClaimedLine: Record "PEN Contribution Queue"; ErrorText: Text; var RunLog: Record "PEN Queue Run Log")
    var
        QueueLine: Record "PEN Contribution Queue";
    begin
        QueueLine.ReadIsolation := IsolationLevel::UpdLock;
        if not QueueLine.Get(ClaimedLine."Batch No.", ClaimedLine."Line No.") then
            exit;
        if not PensionMgt.IsClaimedByThisSession(QueueLine) then
            exit;
        if PensionMgt.MarkLineFailed(QueueLine, ErrorText, PensionSetup."Max Retry Attempts") then
            RunLog."Lines Dead Letter" += 1
        else
            RunLog."Lines Failed" += 1;
    end;

    /// <summary>
    /// A claim is alive while the session that made it is still connected. A claim made by this
    /// very session before this run started can only be left over from an earlier run that failed.
    /// </summary>
    local procedure IsClaimOwnerAlive(QueueLine: Record "PEN Contribution Queue"): Boolean
    var
        ActiveSession: Record "Active Session";
    begin
        if (QueueLine."Claimed By Session ID" = SessionId()) and (QueueLine."Claimed By Server Inst. ID" = ServiceInstanceId()) then
            exit(false);
        ActiveSession.SetRange("Server Instance ID", QueueLine."Claimed By Server Inst. ID");
        ActiveSession.SetRange("Session ID", QueueLine."Claimed By Session ID");
        exit(not ActiveSession.IsEmpty());
    end;

    local procedure ApplyBatchFilter(var QueueLine: Record "PEN Contribution Queue")
    begin
        if BatchFilter <> '' then
            QueueLine.SetRange("Batch No.", BatchFilter);
    end;

    local procedure StartRunLog(var RunLog: Record "PEN Queue Run Log")
    begin
        RunLog.Init();
        RunLog."Entry No." := 0;
        RunLog."Session ID" := SessionId();
        RunLog."Server Instance ID" := ServiceInstanceId();
        RunLog."Started At" := CurrentDateTime();
        RunLog."Batch Size" := PensionSetup."Queue Batch Size";
        RunLog."Batch Filter" := BatchFilter;
        RunLog."User ID" := CopyStr(UserId(), 1, MaxStrLen(RunLog."User ID"));
        RunLog.Insert();
    end;

    local procedure FinishRunLog(var RunLog: Record "PEN Queue Run Log")
    begin
        RunLog."Finished At" := CurrentDateTime();
        RunLog."Duration (ms)" := RunLog."Finished At" - RunLog."Started At";
        if RunLog."Duration (ms)" > 0 then
            RunLog."Lines per Second" := Round(RunLog."Lines Claimed" * 1000 / RunLog."Duration (ms)", 0.1);
        RunLog.Modify();
    end;

    local procedure LogRunTelemetry(RunLog: Record "PEN Queue Run Log")
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('LinesClaimed', Format(RunLog."Lines Claimed", 0, 9));
        Dimensions.Add('LinesPosted', Format(RunLog."Lines Posted", 0, 9));
        Dimensions.Add('LinesFailed', Format(RunLog."Lines Failed", 0, 9));
        Dimensions.Add('LinesDeadLetter', Format(RunLog."Lines Dead Letter", 0, 9));
        Dimensions.Add('Chunks', Format(RunLog.Chunks, 0, 9));
        Dimensions.Add('BatchSize', Format(RunLog."Batch Size", 0, 9));
        Dimensions.Add('DurationMs', Format(RunLog."Duration (ms)", 0, 9));
        Session.LogMessage('PEN0001',
            StrSubstNo(RunFinishedTxt, RunLog."Lines Claimed", RunLog."Lines Posted", RunLog."Lines Failed", RunLog."Lines Dead Letter", RunLog."Duration (ms)"),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    local procedure LogChunkTelemetry(LineCount: Integer; ChunkDuration: Duration)
    var
        Dimensions: Dictionary of [Text, Text];
        DurationMs: BigInteger;
    begin
        DurationMs := ChunkDuration;
        Dimensions.Add('Lines', Format(LineCount, 0, 9));
        Dimensions.Add('DurationMs', Format(DurationMs, 0, 9));
        Session.LogMessage('PEN0002', StrSubstNo(ChunkFinishedTxt, LineCount, DurationMs),
            Verbosity::Verbose, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;
}
