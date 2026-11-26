namespace Zamara.Pension;

page 50111 "PEN Generate Test Data"
{
    Caption = 'Generate Pension Test Data';
    PageType = StandardDialog;
    UsageCategory = Tasks;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Batch)
            {
                Caption = 'Contribution Batches';
                field(PeriodField; Period)
                {
                    Caption = 'Period (YYYY-MM)';
                    ToolTip = 'Specifies the contribution period to create one batch per employer for.';
                }
                field(ReceivedDateField; ReceivedDate)
                {
                    Caption = 'Received Date';
                    ToolTip = 'Specifies the date the batches are received. A date after the due day of the following month makes the batches late, so a penalty is posted.';
                }
                field(BadLinePercentField; BadLinePercent)
                {
                    Caption = 'Bad Lines %';
                    ToolTip = 'Specifies the share of lines that are made to fail on purpose (inactive member, wrong employer, amount over the cap). 0 means none.';
                    DecimalPlaces = 0 : 2;
                    MinValue = 0;
                    MaxValue = 30;
                }
            }
            group(MasterData)
            {
                Caption = 'Master Data';
                field(EmployerCountField; EmployerCount)
                {
                    Caption = 'Employers';
                    ToolTip = 'Specifies how many employers the scheme should have. Existing employers are reused.';
                    MinValue = 1;
                }
                field(MemberCountField; MemberCount)
                {
                    Caption = 'Members';
                    ToolTip = 'Specifies how many members to have in total, spread evenly across the employers. Use 20000 for the performance test.';
                    MinValue = 1;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Period := CopyStr(Format(CalcDate('<-1M>', WorkDate()), 0, '<Year4>-<Month,2>'), 1, MaxStrLen(Period));
        ReceivedDate := WorkDate();
        EmployerCount := 50;
        MemberCount := 2000;
        BadLinePercent := 3;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        TestDataGenerator: Codeunit "PEN Test Data Generator";
        PensionMgt: Codeunit "PEN Pension Mgt";
        PeriodStart: Date;
        PeriodEnd: Date;
    begin
        if CloseAction <> Action::OK then
            exit(true);
        if not PensionMgt.TryParsePeriod(Period, PeriodStart, PeriodEnd) then
            Error(InvalidPeriodErr, Period);
        if ReceivedDate = 0D then
            Error(ReceivedDateErr);
        Message(TestDataGenerator.Generate(Period, ReceivedDate, EmployerCount, MemberCount, BadLinePercent));
        exit(true);
    end;

    var
        Period: Code[7];
        ReceivedDate: Date;
        EmployerCount: Integer;
        MemberCount: Integer;
        BadLinePercent: Decimal;
        InvalidPeriodErr: Label 'Period %1 is not valid. Use the format YYYY-MM.', Comment = '%1 = period';
        ReceivedDateErr: Label 'Enter a received date.';
}
