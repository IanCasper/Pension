namespace Zamara.Pension;

using Microsoft.Sales.Customer;
using System.Utilities;

/// <summary>
/// Member statement over a date range: opening balance, one row per contribution period
/// (employee and employer share, running balance), totals and closing balance.
/// Closing balance = opening balance + contributions in the range, always.
/// </summary>
report 50100 "PEN Member Statement"
{
    Caption = 'Member Statement';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    DefaultRenderingLayout = RDLCLayout;

    dataset
    {
        dataitem(Member; "PEN Member")
        {
            DataItemTableView = sorting("No.");
            RequestFilterFields = "No.", "Employer No.", "Scheme Code";
            PrintOnlyIfDetail = false;

            column(CompanyName; CompanyProperty.DisplayName()) { }
            column(MemberNo; "No.") { }
            column(MemberName; "Full Name") { }
            column(NationalID; "National ID No.") { }
            column(EmployerNo; "Employer No.") { }
            column(EmployerName; EmployerName) { }
            column(SchemeCode; "Scheme Code") { }
            column(SchemeDescription; SchemeDescription) { }
            column(StartDateText; Format(StartDate)) { }
            column(EndDateText; Format(EndDate)) { }
            column(OpeningBalance; OpeningBalance) { AutoFormatType = 1; }
            column(ClosingBalance; ClosingBalance) { AutoFormatType = 1; }
            column(TotalEmployee; TotalEmployee) { AutoFormatType = 1; }
            column(TotalEmployer; TotalEmployer) { AutoFormatType = 1; }
            column(TotalContributions; TotalEmployee + TotalEmployer) { AutoFormatType = 1; }
            column(TitleCaption; TitleLbl) { }
            column(MemberCaption; MemberLbl) { }
            column(NationalIDCaption; NationalIDLbl) { }
            column(EmployerCaption; EmployerNameLbl) { }
            column(SchemeCaption; SchemeLbl) { }
            column(StatementPeriodCaption; StatementPeriodLbl) { }
            column(ToCaption; ToLbl) { }
            column(PeriodCaption; PeriodLbl) { }
            column(PostingDateCaption; PostingDateLbl) { }
            column(DescriptionCaption; DescriptionLbl) { }
            column(EmployeeCaption; EmployeeLbl) { }
            column(EmployerAmountCaption; EmployerLbl) { }
            column(TotalCaption; TotalLbl) { }
            column(BalanceCaption; RunningBalanceLbl) { }
            column(OpeningBalanceCaption; OpeningBalanceLbl) { }
            column(ClosingBalanceCaption; ClosingBalanceLbl) { }
            column(TotalsCaption; TotalsLbl) { }

            dataitem(StatementLine; Integer)
            {
                DataItemTableView = sorting(Number);

                column(LineNo; Number) { }
                column(LinePeriod; TempStatementBuffer.Period) { }
                column(LinePostingDate; Format(TempStatementBuffer."Posting Date")) { }
                column(LineDescription; TempStatementBuffer.Description) { }
                column(LineEmployee; TempStatementBuffer."Employee Amount") { AutoFormatType = 1; }
                column(LineEmployer; TempStatementBuffer."Employer Amount") { AutoFormatType = 1; }
                column(LineTotal; TempStatementBuffer."Total Amount") { AutoFormatType = 1; }
                column(LineRunningBalance; TempStatementBuffer."Running Balance") { AutoFormatType = 1; }

                trigger OnPreDataItem()
                begin
                    TempStatementBuffer.Reset();
                    SetRange(Number, 1, TempStatementBuffer.Count());
                end;

                trigger OnAfterGetRecord()
                begin
                    if Number = 1 then
                        TempStatementBuffer.FindSet()
                    else
                        TempStatementBuffer.Next();
                end;
            }

            trigger OnAfterGetRecord()
            begin
                LookUpNames();
                BuildStatement();
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(StartDateField; StartDate)
                    {
                        ApplicationArea = All;
                        Caption = 'Start Date';
                        ToolTip = 'Specifies the first date of the statement. The opening balance is the balance on the day before.';
                    }
                    field(EndDateField; EndDate)
                    {
                        ApplicationArea = All;
                        Caption = 'End Date';
                        ToolTip = 'Specifies the last date of the statement.';
                    }
                }
            }
        }

        trigger OnOpenPage()
        begin
            if StartDate = 0D then
                StartDate := CalcDate('<-CY>', WorkDate());
            if EndDate = 0D then
                EndDate := CalcDate('<CM>', WorkDate());
        end;
    }

    rendering
    {
        layout(RDLCLayout)
        {
            Type = RDLC;
            LayoutFile = './src/Reports/Layouts/PENMemberStatement.rdlc';
            Caption = 'Member Statement (RDLC)';
        }
    }


    trigger OnPreReport()
    begin
        if StartDate = 0D then
            Error(StartDateErr);
        if EndDate = 0D then
            Error(EndDateErr);
        if EndDate < StartDate then
            Error(DateOrderErr);
    end;

    var
        TempStatementBuffer: Record "PEN Statement Buffer" temporary;
        StartDate: Date;
        EndDate: Date;
        OpeningBalance: Decimal;
        ClosingBalance: Decimal;
        TotalEmployee: Decimal;
        TotalEmployer: Decimal;
        EmployerName: Text[100];
        SchemeDescription: Text[100];
        StartDateErr: Label 'Enter a start date.';
        EndDateErr: Label 'Enter an end date.';
        DateOrderErr: Label 'The end date must be on or after the start date.';
        ContributionsTxt: Label 'Contributions %1', Comment = '%1 = period';
        NoActivityTxt: Label 'No contributions in this period';
        TitleLbl: Label 'Member Statement';
        MemberLbl: Label 'Member';
        NationalIDLbl: Label 'National ID';
        EmployerNameLbl: Label 'Employer';
        SchemeLbl: Label 'Scheme';
        StatementPeriodLbl: Label 'Statement period';
        ToLbl: Label 'to';
        PeriodLbl: Label 'Period';
        PostingDateLbl: Label 'Posting Date';
        DescriptionLbl: Label 'Description';
        EmployeeLbl: Label 'Employee';
        EmployerLbl: Label 'Employer';
        TotalLbl: Label 'Total';
        RunningBalanceLbl: Label 'Balance';
        OpeningBalanceLbl: Label 'Opening balance';
        ClosingBalanceLbl: Label 'Closing balance';
        TotalsLbl: Label 'Total contributions';

    /// <summary>
    /// Sets the date range when the report is run from code (tests, other reports).
    /// </summary>
    procedure SetDateRange(NewStartDate: Date; NewEndDate: Date)
    begin
        StartDate := NewStartDate;
        EndDate := NewEndDate;
    end;

    local procedure LookUpNames()
    var
        Employer: Record Customer;
        Scheme: Record "PEN Scheme";
    begin
        EmployerName := '';
        SchemeDescription := '';
        Employer.SetLoadFields(Name);
        if Employer.Get(Member."Employer No.") then
            EmployerName := Employer.Name;
        Scheme.SetLoadFields(Description);
        if Scheme.Get(Member."Scheme Code") then
            SchemeDescription := Scheme.Description;
    end;

    local procedure BuildStatement()
    var
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
        EntryNoByPeriod: Dictionary of [Code[7], Integer];
        RunningBalance: Decimal;
        NextEntryNo: Integer;
    begin
        TempStatementBuffer.Reset();
        TempStatementBuffer.DeleteAll();
        TotalEmployee := 0;
        TotalEmployer := 0;

        // Opening balance: everything posted before the start date.
        MemberLedgerEntry.SetCurrentKey("Member No.", "Posting Date");
        MemberLedgerEntry.SetRange("Member No.", Member."No.");
        MemberLedgerEntry.SetFilter("Posting Date", '..%1', CalcDate('<-1D>', StartDate));
        MemberLedgerEntry.CalcSums(Amount);
        OpeningBalance := MemberLedgerEntry.Amount;

        // One row per period inside the range, in date order.
        MemberLedgerEntry.SetRange("Posting Date", StartDate, EndDate);
        MemberLedgerEntry.SetLoadFields("Posting Date", Period, "Entry Type", Amount);
        if MemberLedgerEntry.FindSet() then
            repeat
                if EntryNoByPeriod.ContainsKey(MemberLedgerEntry.Period) then
                    TempStatementBuffer.Get(EntryNoByPeriod.Get(MemberLedgerEntry.Period))
                else begin
                    NextEntryNo += 1;
                    TempStatementBuffer.Init();
                    TempStatementBuffer."Entry No." := NextEntryNo;
                    TempStatementBuffer.Period := MemberLedgerEntry.Period;
                    TempStatementBuffer."Posting Date" := MemberLedgerEntry."Posting Date";
                    TempStatementBuffer.Description := StrSubstNo(ContributionsTxt, MemberLedgerEntry.Period);
                    TempStatementBuffer.Insert();
                    EntryNoByPeriod.Add(MemberLedgerEntry.Period, NextEntryNo);
                end;
                case MemberLedgerEntry."Entry Type" of
                    MemberLedgerEntry."Entry Type"::"Employee Contribution":
                        begin
                            TempStatementBuffer."Employee Amount" += MemberLedgerEntry.Amount;
                            TotalEmployee += MemberLedgerEntry.Amount;
                        end;
                    MemberLedgerEntry."Entry Type"::"Employer Contribution":
                        begin
                            TempStatementBuffer."Employer Amount" += MemberLedgerEntry.Amount;
                            TotalEmployer += MemberLedgerEntry.Amount;
                        end;
                end;
                TempStatementBuffer."Total Amount" := TempStatementBuffer."Employee Amount" + TempStatementBuffer."Employer Amount";
                TempStatementBuffer.Modify();
            until MemberLedgerEntry.Next() = 0;

        RunningBalance := OpeningBalance;
        TempStatementBuffer.SetCurrentKey("Posting Date", Period);
        if TempStatementBuffer.FindSet() then
            repeat
                RunningBalance += TempStatementBuffer."Total Amount";
                TempStatementBuffer."Running Balance" := RunningBalance;
                TempStatementBuffer.Modify();
            until TempStatementBuffer.Next() = 0
        else begin
            // A member with no entries in the range still gets a statement showing the balance.
            TempStatementBuffer.Init();
            TempStatementBuffer."Entry No." := 1;
            TempStatementBuffer."Posting Date" := EndDate;
            TempStatementBuffer.Description := NoActivityTxt;
            TempStatementBuffer."Running Balance" := OpeningBalance;
            TempStatementBuffer.Insert();
        end;

        ClosingBalance := OpeningBalance + TotalEmployee + TotalEmployer;
        TempStatementBuffer.Reset();
    end;
}
