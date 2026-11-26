namespace Zamara.Pension;

using Microsoft.Utilities;

/// <summary>
/// The five most common errors on Failed and Dead Letter lines. Digits are masked before
/// grouping, so "Member MEM00012 is Exited" and "Member MEM00345 is Exited" count as one error.
/// </summary>
page 50121 "PEN Top Errors Part"
{
    Caption = 'Most Common Errors';
    PageType = ListPart;
    SourceTable = "Name/Value Buffer";
    SourceTableTemporary = true;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Errors)
            {
                field(ErrorText; Rec.Name)
                {
                    Caption = 'Error';
                    ToolTip = 'Specifies the error, with numbers masked as #.';
                }
                field(Occurrences; Rec.Value)
                {
                    Caption = 'Lines';
                    ToolTip = 'Specifies how many Failed or Dead Letter lines have this error.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        LoadTopErrors();
    end;

    procedure LoadTopErrors()
    var
        QueueLine: Record "PEN Contribution Queue";
        ErrorCounts: Dictionary of [Text, Integer];
        ErrorKey: Text;
        TopKey: Text;
        TopCount: Integer;
        Rank: Integer;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        QueueLine.SetCurrentKey(Status, "Batch No.", "Line No.");
        QueueLine.SetFilter(Status, '%1|%2', QueueLine.Status::Failed, QueueLine.Status::"Dead Letter");
        QueueLine.SetLoadFields(Status, "Last Error");
        if QueueLine.FindSet() then
            repeat
                ErrorKey := CopyStr(ConvertStr(QueueLine."Last Error", '0123456789', '##########'), 1, MaxStrLen(Rec.Name));
                if ErrorCounts.ContainsKey(ErrorKey) then
                    ErrorCounts.Set(ErrorKey, ErrorCounts.Get(ErrorKey) + 1)
                else
                    ErrorCounts.Add(ErrorKey, 1);
            until QueueLine.Next() = 0;

        while (Rank < 5) and (ErrorCounts.Count() > 0) do begin
            TopKey := '';
            TopCount := 0;
            foreach ErrorKey in ErrorCounts.Keys() do
                if ErrorCounts.Get(ErrorKey) > TopCount then begin
                    TopKey := ErrorKey;
                    TopCount := ErrorCounts.Get(ErrorKey);
                end;
            Rank += 1;
            Rec.Init();
            Rec.ID := Rank;
            Rec.Name := CopyStr(TopKey, 1, MaxStrLen(Rec.Name));
            Rec.Value := Format(TopCount);
            Rec.Insert();
            ErrorCounts.Remove(TopKey);
        end;
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;
}
