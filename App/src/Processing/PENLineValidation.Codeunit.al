namespace Zamara.Pension;

using Microsoft.Sales.Customer;

/// <summary>
/// Business validation of one queue line. It only reads, and it returns the error text instead
/// of raising an error, so one bad line never stops the others and no TryFunction is needed.
/// Member, employer and scheme records are cached for the lifetime of one processor run.
/// </summary>
codeunit 50102 "PEN Line Validation"
{
    var
        TempMemberCache: Record "PEN Member" temporary;
        TempEmployerCache: Record Customer temporary;
        TempSchemeCache: Record "PEN Scheme" temporary;
        MissingMembers: Dictionary of [Code[20], Boolean];
        MissingEmployers: Dictionary of [Code[20], Boolean];
        MissingSchemes: Dictionary of [Code[20], Boolean];
        PostedInThisRun: Dictionary of [Text, Boolean];
        MemberNotFoundErr: Label 'Member %1 does not exist.', Comment = '%1 = member no.';
        MemberNotActiveErr: Label 'Member %1 is %2, not Active.', Comment = '%1 = member no., %2 = status';
        MemberWrongEmployerErr: Label 'Member %1 belongs to employer %2, not to the batch employer %3.', Comment = '%1 = member, %2 = member employer, %3 = batch employer';
        EmployerNotFoundErr: Label 'Employer %1 does not exist.', Comment = '%1 = employer no.';
        NotPensionEmployerErr: Label 'Customer %1 is not a pension employer.', Comment = '%1 = customer no.';
        EmployerNotActiveErr: Label 'Employer %1 is %2, not Active.', Comment = '%1 = employer no., %2 = status';
        EmployerNoSchemeErr: Label 'Employer %1 has no scheme.', Comment = '%1 = employer no.';
        SchemeNotFoundErr: Label 'Scheme %1 does not exist.', Comment = '%1 = scheme code';
        SchemeBlockedErr: Label 'Scheme %1 is blocked.', Comment = '%1 = scheme code';
        AlreadyPostedErr: Label 'A contribution for member %1 and period %2 has already been posted.', Comment = '%1 = member, %2 = period';
        DuplicateInRunErr: Label 'Member %1 appears more than once for period %2; the earlier line is being posted.', Comment = '%1 = member, %2 = period';
        OverCapErr: Label 'Employer amount %1 exceeds the scheme cap of %2% of pensionable salary %3 (maximum %4).', Comment = '%1 = employer amount, %2 = cap %, %3 = salary, %4 = maximum';

    /// <summary>
    /// Validates a queue line. On success it also stamps the line's Scheme Code so posting does not need to look it up again.
    /// </summary>
    procedure ValidateLine(var QueueLine: Record "PEN Contribution Queue"; var ErrorText: Text): Boolean
    var
        IsHandled: Boolean;
    begin
        ErrorText := '';
        OnBeforeValidateQueueLine(QueueLine, ErrorText, IsHandled);
        if not IsHandled then
            ErrorText := RunChecks(QueueLine);
        OnAfterValidateQueueLine(QueueLine, ErrorText);
        if ErrorText <> '' then
            exit(false);
        PostedInThisRun.Set(MemberPeriodKey(QueueLine."Member No.", QueueLine.Period), true);
        exit(true);
    end;

    /// <summary>
    /// Clears the caches. Call it at the start of every processor run, so master-data changes made between runs are seen.
    /// </summary>
    procedure ResetCache()
    begin
        TempMemberCache.Reset();
        TempMemberCache.DeleteAll();
        TempEmployerCache.Reset();
        TempEmployerCache.DeleteAll();
        TempSchemeCache.Reset();
        TempSchemeCache.DeleteAll();
        Clear(MissingMembers);
        Clear(MissingEmployers);
        Clear(MissingSchemes);
        Clear(PostedInThisRun);
    end;

    /// <summary>
    /// Forgets a line that passed validation but did not get posted (the posting chunk failed),
    /// so its retry is not reported as a duplicate.
    /// </summary>
    procedure ForgetLine(QueueLine: Record "PEN Contribution Queue")
    var
        MapKey: Text;
    begin
        MapKey := MemberPeriodKey(QueueLine."Member No.", QueueLine.Period);
        if PostedInThisRun.ContainsKey(MapKey) then
            PostedInThisRun.Remove(MapKey);
    end;

    local procedure RunChecks(var QueueLine: Record "PEN Contribution Queue"): Text
    var
        Member: Record "PEN Member";
        Employer: Record Customer;
        Scheme: Record "PEN Scheme";
        MaxEmployerAmount: Decimal;
    begin
        // The member exists, is active and belongs to the batch's employer.
        if not GetMember(QueueLine."Member No.", Member) then
            exit(StrSubstNo(MemberNotFoundErr, QueueLine."Member No."));
        if Member.Status <> Member.Status::Active then
            exit(StrSubstNo(MemberNotActiveErr, Member."No.", Member.Status));
        if Member."Employer No." <> QueueLine."Employer No." then
            exit(StrSubstNo(MemberWrongEmployerErr, Member."No.", Member."Employer No.", QueueLine."Employer No."));

        // The employer is active and its scheme is not blocked.
        if not GetEmployer(QueueLine."Employer No.", Employer) then
            exit(StrSubstNo(EmployerNotFoundErr, QueueLine."Employer No."));
        if not Employer."PEN Pension Employer" then
            exit(StrSubstNo(NotPensionEmployerErr, Employer."No."));
        if Employer."PEN Employer Status" <> Employer."PEN Employer Status"::Active then
            exit(StrSubstNo(EmployerNotActiveErr, Employer."No.", Employer."PEN Employer Status"));
        if Employer."PEN Scheme Code" = '' then
            exit(StrSubstNo(EmployerNoSchemeErr, Employer."No."));
        if not GetScheme(Employer."PEN Scheme Code", Scheme) then
            exit(StrSubstNo(SchemeNotFoundErr, Employer."PEN Scheme Code"));
        if Scheme.Blocked then
            exit(StrSubstNo(SchemeBlockedErr, Scheme.Code));

        // No posted line for the same member and period.
        if PostedInThisRun.ContainsKey(MemberPeriodKey(QueueLine."Member No.", QueueLine.Period)) then
            exit(StrSubstNo(DuplicateInRunErr, QueueLine."Member No.", QueueLine.Period));
        if IsAlreadyPosted(QueueLine) then
            exit(StrSubstNo(AlreadyPostedErr, QueueLine."Member No.", QueueLine.Period));

        // The employer amount is within the scheme cap. A cap of 0 means the scheme has no cap.
        if Scheme."Employer Cap %" > 0 then begin
            MaxEmployerAmount := Round(Member."Pensionable Salary" * Scheme."Employer Cap %" / 100);
            if QueueLine."Employer Amount" > MaxEmployerAmount then
                exit(StrSubstNo(OverCapErr, QueueLine."Employer Amount", Scheme."Employer Cap %", Member."Pensionable Salary", MaxEmployerAmount));
        end;

        QueueLine."Scheme Code" := Scheme.Code;
        exit('');
    end;

    local procedure IsAlreadyPosted(QueueLine: Record "PEN Contribution Queue"): Boolean
    var
        PostedLine: Record "PEN Contribution Queue";
    begin
        PostedLine.SetCurrentKey("Member No.", Period, Status);
        PostedLine.SetRange("Member No.", QueueLine."Member No.");
        PostedLine.SetRange(Period, QueueLine.Period);
        PostedLine.SetRange(Status, PostedLine.Status::Posted);
        PostedLine.ReadIsolation := IsolationLevel::ReadCommitted;
        exit(not PostedLine.IsEmpty());
    end;

    local procedure GetMember(MemberNo: Code[20]; var Member: Record "PEN Member"): Boolean
    begin
        if TempMemberCache.Get(MemberNo) then begin
            Member := TempMemberCache;
            exit(true);
        end;
        if MissingMembers.ContainsKey(MemberNo) then
            exit(false);
        Member.ReadIsolation := IsolationLevel::ReadCommitted;
        Member.SetLoadFields("No.", Status, "Employer No.", "Scheme Code", "Pensionable Salary");
        if not Member.Get(MemberNo) then begin
            MissingMembers.Add(MemberNo, true);
            exit(false);
        end;
        TempMemberCache := Member;
        TempMemberCache.Insert();
        exit(true);
    end;

    local procedure GetEmployer(EmployerNo: Code[20]; var Employer: Record Customer): Boolean
    begin
        if TempEmployerCache.Get(EmployerNo) then begin
            Employer := TempEmployerCache;
            exit(true);
        end;
        if MissingEmployers.ContainsKey(EmployerNo) then
            exit(false);
        Employer.ReadIsolation := IsolationLevel::ReadCommitted;
        Employer.SetLoadFields("No.", "PEN Pension Employer", "PEN Employer Status", "PEN Scheme Code");
        if not Employer.Get(EmployerNo) then begin
            MissingEmployers.Add(EmployerNo, true);
            exit(false);
        end;
        TempEmployerCache := Employer;
        TempEmployerCache.Insert();
        exit(true);
    end;

    local procedure GetScheme(SchemeCode: Code[20]; var Scheme: Record "PEN Scheme"): Boolean
    begin
        if TempSchemeCache.Get(SchemeCode) then begin
            Scheme := TempSchemeCache;
            exit(true);
        end;
        if MissingSchemes.ContainsKey(SchemeCode) then
            exit(false);
        Scheme.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Scheme.Get(SchemeCode) then begin
            MissingSchemes.Add(SchemeCode, true);
            exit(false);
        end;
        TempSchemeCache := Scheme;
        TempSchemeCache.Insert();
        exit(true);
    end;

    local procedure MemberPeriodKey(MemberNo: Code[20]; Period: Code[7]): Text
    begin
        exit(MemberNo + '|' + Period);
    end;

    /// <summary>
    /// Raised before the standard checks. Set IsHandled to replace them. Subscribers must not
    /// write to the database or raise errors: report a failure by setting ErrorText.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnBeforeValidateQueueLine(var QueueLine: Record "PEN Contribution Queue"; var ErrorText: Text; var IsHandled: Boolean)
    begin
    end;

    /// <summary>
    /// Raised after the standard checks. Set ErrorText to fail the line with your own rule.
    /// Subscribers must not write to the database or raise errors.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnAfterValidateQueueLine(QueueLine: Record "PEN Contribution Queue"; var ErrorText: Text)
    begin
    end;
}
