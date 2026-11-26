namespace Zamara.Pension;

using Microsoft.Foundation.NoSeries;

/// <summary>
/// Receives contribution batches. Every route (JSON file, CSV file, API page, data generator)
/// parses into the same buffers and calls ReceiveBatch, so the rules are identical everywhere.
/// Intake does structural checks only; business validation runs later in the background.
/// </summary>
codeunit 50100 "PEN Contribution Intake"
{
    var
        SelectFileTxt: Label 'Select a contribution file (JSON or CSV)';
        FileFilterTxt: Label 'Contribution files (*.json;*.csv)|*.json;*.csv|JSON files (*.json)|*.json|CSV files (*.csv)|*.csv', Locked = true;
        UnsupportedFileErr: Label 'File %1 is not supported. Upload a .json or .csv file.', Comment = '%1 = file name';
        BatchReceivedMsg: Label 'Batch %1 received with %2 lines. The lines are Pending and will be processed in the background.', Comment = '%1 = batch no., %2 = line count';
        MissingFieldErr: Label 'The file is missing the required field "%1".', Comment = '%1 = JSON/CSV field name';
        MissingLineFieldErr: Label 'Line %1 is missing the required field "%2".', Comment = '%1 = line no., %2 = field name';
        InvalidNumberErr: Label 'Field "%1" has value "%2", which is not a valid number.', Comment = '%1 = field, %2 = value';
        InvalidLineNumberErr: Label 'Line %1: field "%2" has value "%3", which is not a valid number.', Comment = '%1 = line, %2 = field, %3 = value';
        InvalidDateErr: Label 'Field "%1" has value "%2", which is not a valid date. Use YYYY-MM-DD.', Comment = '%1 = field, %2 = value';
        InvalidPeriodErr: Label 'Period "%1" is not valid. Use the format YYYY-MM.', Comment = '%1 = period';
        NotAJsonObjectErr: Label 'The file is not a valid JSON object.';
        LinesNotArrayErr: Label 'The field "lines" must be a JSON array of line objects.';
        LineNotObjectErr: Label 'Line %1 is not a JSON object.', Comment = '%1 = line no.';
        NoLinesErr: Label 'The batch has no lines.';
        DuplicateMessageErr: Label 'Message ID %1 has already been received as batch %2. The same file cannot be loaded twice.', Comment = '%1 = message ID, %2 = batch no.';
        ControlTotalErr: Label 'The batch is rejected: the line amounts add up to %1, but the control total is %2 (difference %3).', Comment = '%1 = sum of lines, %2 = control total, %3 = difference';
        NegativeAmountErr: Label 'Line %1 (member %2) has a negative amount.', Comment = '%1 = line no., %2 = member no.';
        ZeroLineErr: Label 'Line %1 (member %2) has no employee or employer amount.', Comment = '%1 = line no., %2 = member no.';
        CsvHeaderMissingErr: Label 'The CSV file has no header row.';
        CsvColumnMissingErr: Label 'The CSV header is missing the column "%1".', Comment = '%1 = column name';
        CsvColumnCountErr: Label 'CSV row %1 has %2 columns, but the header has %3.', Comment = '%1 = row, %2 = found, %3 = expected';
        CsvInconsistentErr: Label 'CSV row %1: "%2" is "%3", but the first row has "%4". All rows must belong to the same batch.', Comment = '%1 = row, %2 = column, %3 = value, %4 = first value';
        ValueTooLongErr: Label 'Field "%1" is longer than %2 characters.', Comment = '%1 = field, %2 = max length';

    /// <summary>
    /// Page action: asks for a file and receives it. Returns the new batch no.
    /// </summary>
    procedure ImportFromFile(): Code[20]
    var
        Batch: Record "PEN Contribution Batch";
        InStr: InStream;
        FileName: Text;
        BatchNo: Code[20];
    begin
        if not UploadIntoStream(SelectFileTxt, '', FileFilterTxt, FileName, InStr) then
            exit('');
        case GetFileExtension(FileName) of
            'json':
                BatchNo := ImportJson(InStr, "PEN Intake Source"::"JSON File");
            'csv':
                BatchNo := ImportCsv(InStr);
            else
                Error(UnsupportedFileErr, FileName);
        end;
        Batch.Get(BatchNo);
        Message(BatchReceivedMsg, Batch."No.", Batch."No. of Lines");
        exit(BatchNo);
    end;

    procedure ImportJson(var InStr: InStream; Source: Enum "PEN Intake Source"): Code[20]
    var
        TempBatch: Record "PEN Contribution Batch" temporary;
        TempLine: Record "PEN Intake Line Buffer" temporary;
        JObject: JsonObject;
    begin
        if not JObject.ReadFrom(InStr) then
            Error(NotAJsonObjectErr);
        ParseJson(JObject, TempBatch, TempLine);
        exit(ReceiveBatch(TempBatch, TempLine, Source));
    end;

    procedure ImportJsonText(JsonText: Text; Source: Enum "PEN Intake Source"): Code[20]
    var
        TempBatch: Record "PEN Contribution Batch" temporary;
        TempLine: Record "PEN Intake Line Buffer" temporary;
        JObject: JsonObject;
    begin
        if not JObject.ReadFrom(JsonText) then
            Error(NotAJsonObjectErr);
        ParseJson(JObject, TempBatch, TempLine);
        exit(ReceiveBatch(TempBatch, TempLine, Source));
    end;

    procedure ImportCsv(var InStr: InStream): Code[20]
    var
        TempBatch: Record "PEN Contribution Batch" temporary;
        TempLine: Record "PEN Intake Line Buffer" temporary;
    begin
        ParseCsv(InStr, TempBatch, TempLine);
        exit(ReceiveBatch(TempBatch, TempLine, "PEN Intake Source"::"CSV File"));
    end;

    /// <summary>
    /// API route: receives the JSON payload and records the request for audit.
    /// An intake error is raised to the caller, so the API returns HTTP 400 with the message.
    /// </summary>
    procedure ReceiveFromApi(var IntakeRequest: Record "PEN API Intake Request"; PayloadText: Text)
    var
        Batch: Record "PEN Contribution Batch";
        OutStr: OutStream;
    begin
        IntakeRequest."Batch No." := ImportJsonText(PayloadText, "PEN Intake Source"::API);
        Batch.Get(IntakeRequest."Batch No.");
        IntakeRequest."Message ID" := Batch."Message ID";
        IntakeRequest."No. of Lines" := Batch."No. of Lines";
        IntakeRequest."Received At" := Batch."Received At";
        IntakeRequest."Received By" := Batch."Received By";
        IntakeRequest.Payload.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(PayloadText);
    end;

    /// <summary>
    /// The single entry point for every intake route. Runs the structural checks, then creates
    /// the batch header and one Pending queue line per member line. All or nothing.
    /// </summary>
    procedure ReceiveBatch(var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Intake Line Buffer" temporary; Source: Enum "PEN Intake Source"): Code[20]
    var
        Batch: Record "PEN Contribution Batch";
        QueueLine: Record "PEN Contribution Queue";
        PensionSetup: Record "PEN Pension Setup";
        PensionMgt: Codeunit "PEN Pension Mgt";
        NoSeries: Codeunit "No. Series";
        LineTotal: Decimal;
        LineCount: Integer;
    begin
        CheckStructure(TempBatch, TempLine, LineTotal, LineCount);
        OnBeforeReceiveBatch(TempBatch, TempLine);

        PensionSetup.GetSetup();
        PensionSetup.TestField("Contribution Batch Nos.");

        Batch.Init();
        Batch."No. Series" := PensionSetup."Contribution Batch Nos.";
        Batch."No." := NoSeries.GetNextNo(Batch."No. Series");
        Batch."Message ID" := TempBatch."Message ID";
        Batch."Employer No." := TempBatch."Employer No.";
        Batch.Period := TempBatch.Period;
        Batch."Received Date" := TempBatch."Received Date";
        Batch."Control Total" := TempBatch."Control Total";
        Batch."Line Total" := LineTotal;
        Batch."No. of Lines" := LineCount;
        Batch.Source := Source;
        Batch."Received By" := CopyStr(UserId(), 1, MaxStrLen(Batch."Received By"));
        Batch."Received At" := CurrentDateTime();
        Batch."Due Date" := PensionMgt.GetDueDate(Batch.Period, PensionSetup."Remittance Due Day");
        Batch.Status := Batch.Status::Received;
        // The unique key on Message ID backs up the CheckStructure lookup if two uploads race.
        Batch.Insert();

        TempLine.Reset();
        TempLine.FindSet();
        repeat
            QueueLine.Init();
            QueueLine."Batch No." := Batch."No.";
            QueueLine."Line No." := TempLine."Line No.";
            QueueLine."Employer No." := Batch."Employer No.";
            QueueLine."Member No." := TempLine."Member No.";
            QueueLine.Period := Batch.Period;
            QueueLine."Employee Amount" := TempLine."Employee Amount";
            QueueLine."Employer Amount" := TempLine."Employer Amount";
            QueueLine."Line Amount" := TempLine."Employee Amount" + TempLine."Employer Amount";
            QueueLine.Status := QueueLine.Status::Pending;
            QueueLine.Insert();
        until TempLine.Next() = 0;

        OnAfterReceiveBatch(Batch);
        exit(Batch."No.");
    end;

    /// <summary>
    /// True when a batch with this message ID has already been received.
    /// </summary>
    procedure IsMessageReceived(MessageID: Text[100]; var ExistingBatchNo: Code[20]): Boolean
    var
        Batch: Record "PEN Contribution Batch";
    begin
        ExistingBatchNo := '';
        Batch.SetCurrentKey("Message ID");
        Batch.SetRange("Message ID", MessageID);
        Batch.SetLoadFields("No.");
        if not Batch.FindFirst() then
            exit(false);
        ExistingBatchNo := Batch."No.";
        exit(true);
    end;

    local procedure CheckStructure(var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Intake Line Buffer" temporary; var LineTotal: Decimal; var LineCount: Integer)
    var
        PensionMgt: Codeunit "PEN Pension Mgt";
        ExistingBatchNo: Code[20];
        PeriodStart: Date;
        PeriodEnd: Date;
    begin
        if TempBatch."Message ID" = '' then
            Error(MissingFieldErr, 'messageId');
        if TempBatch."Employer No." = '' then
            Error(MissingFieldErr, 'employerNo');
        if not PensionMgt.TryParsePeriod(TempBatch.Period, PeriodStart, PeriodEnd) then
            Error(InvalidPeriodErr, TempBatch.Period);
        if TempBatch."Received Date" = 0D then
            Error(MissingFieldErr, 'receivedDate');
        if IsMessageReceived(TempBatch."Message ID", ExistingBatchNo) then
            Error(DuplicateMessageErr, TempBatch."Message ID", ExistingBatchNo);

        LineTotal := 0;
        LineCount := 0;
        TempLine.Reset();
        if not TempLine.FindSet() then
            Error(NoLinesErr);
        repeat
            if TempLine."Member No." = '' then
                Error(MissingLineFieldErr, TempLine."Line No.", 'memberNo');
            if (TempLine."Employee Amount" < 0) or (TempLine."Employer Amount" < 0) then
                Error(NegativeAmountErr, TempLine."Line No.", TempLine."Member No.");
            if TempLine."Employee Amount" + TempLine."Employer Amount" = 0 then
                Error(ZeroLineErr, TempLine."Line No.", TempLine."Member No.");
            LineTotal += TempLine."Employee Amount" + TempLine."Employer Amount";
            LineCount += 1;
        until TempLine.Next() = 0;

        if LineTotal <> TempBatch."Control Total" then
            Error(ControlTotalErr, LineTotal, TempBatch."Control Total", LineTotal - TempBatch."Control Total");
    end;

    local procedure ParseJson(JObject: JsonObject; var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Intake Line Buffer" temporary)
    var
        LinesToken: JsonToken;
        LineToken: JsonToken;
        LineObject: JsonObject;
        LineNo: Integer;
    begin
        TempBatch.Init();
        TempBatch."Message ID" := CopyStr(GetJsonText(JObject, 'messageId', MaxStrLen(TempBatch."Message ID")), 1, MaxStrLen(TempBatch."Message ID"));
        TempBatch."Employer No." := CopyStr(GetJsonText(JObject, 'employerNo', MaxStrLen(TempBatch."Employer No.")), 1, MaxStrLen(TempBatch."Employer No."));
        TempBatch.Period := CopyStr(GetJsonText(JObject, 'period', MaxStrLen(TempBatch.Period)), 1, MaxStrLen(TempBatch.Period));
        TempBatch."Received Date" := ParseDate(GetJsonText(JObject, 'receivedDate', 10), 'receivedDate');
        TempBatch."Control Total" := ParseDecimal(GetJsonText(JObject, 'controlTotal', 50), 'controlTotal', 0);

        if not JObject.Get('lines', LinesToken) then
            Error(MissingFieldErr, 'lines');
        if not LinesToken.IsArray() then
            Error(LinesNotArrayErr);

        foreach LineToken in LinesToken.AsArray() do begin
            LineNo += 1;
            if not LineToken.IsObject() then
                Error(LineNotObjectErr, LineNo);
            LineObject := LineToken.AsObject();
            TempLine.Init();
            TempLine."Line No." := LineNo;
            TempLine."Source Line No." := LineNo;
            TempLine."Member No." := CopyStr(GetJsonLineText(LineObject, 'memberNo', LineNo, MaxStrLen(TempLine."Member No.")), 1, MaxStrLen(TempLine."Member No."));
            TempLine."Employee Amount" := ParseDecimal(GetJsonLineText(LineObject, 'employeeAmount', LineNo, 50), 'employeeAmount', LineNo);
            TempLine."Employer Amount" := ParseDecimal(GetJsonLineText(LineObject, 'employerAmount', LineNo, 50), 'employerAmount', LineNo);
            TempLine.Insert();
        end;
    end;

    local procedure ParseCsv(var InStr: InStream; var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Intake Line Buffer" temporary)
    var
        Columns: Dictionary of [Text, Integer];
        FirstRowValues: Dictionary of [Text, Text];
        Values: List of [Text];
        BatchColumns: List of [Text];
        LineColumns: List of [Text];
        ColumnName: Text;
        RowText: Text;
        CellValue: Text;
        RowNo: Integer;
        LineNo: Integer;
        HeaderRead: Boolean;
    begin
        BatchColumns.AddRange('messageid', 'employerno', 'period', 'receiveddate', 'controltotal');
        LineColumns.AddRange('memberno', 'employeeamount', 'employeramount');

        while not InStr.EOS() do begin
            InStr.ReadText(RowText);
            RowNo += 1;
            RowText := StripBom(RowText).Trim();
            if RowText <> '' then
                if not HeaderRead then begin
                    ReadCsvHeader(RowText, Columns);
                    foreach ColumnName in BatchColumns do
                        if not Columns.ContainsKey(ColumnName) then
                            Error(CsvColumnMissingErr, ColumnName);
                    foreach ColumnName in LineColumns do
                        if not Columns.ContainsKey(ColumnName) then
                            Error(CsvColumnMissingErr, ColumnName);
                    HeaderRead := true;
                end else begin
                    Values := SplitCsvRow(RowText);
                    if Values.Count() <> Columns.Count() then
                        Error(CsvColumnCountErr, RowNo, Values.Count(), Columns.Count());

                    // Batch details repeat on every row; take them from the first row and require the rest to match.
                    foreach ColumnName in BatchColumns do begin
                        CellValue := Values.Get(Columns.Get(ColumnName));
                        if not FirstRowValues.ContainsKey(ColumnName) then
                            FirstRowValues.Add(ColumnName, CellValue)
                        else
                            if FirstRowValues.Get(ColumnName) <> CellValue then
                                Error(CsvInconsistentErr, RowNo, ColumnName, CellValue, FirstRowValues.Get(ColumnName));
                    end;

                    LineNo += 1;
                    TempLine.Init();
                    TempLine."Line No." := LineNo;
                    TempLine."Source Line No." := RowNo;
                    TempLine."Member No." := CopyStr(CheckLength(Values.Get(Columns.Get('memberno')), 'memberNo', MaxStrLen(TempLine."Member No.")), 1, MaxStrLen(TempLine."Member No."));
                    TempLine."Employee Amount" := ParseDecimal(Values.Get(Columns.Get('employeeamount')), 'employeeAmount', LineNo);
                    TempLine."Employer Amount" := ParseDecimal(Values.Get(Columns.Get('employeramount')), 'employerAmount', LineNo);
                    TempLine.Insert();
                end;
        end;

        if not HeaderRead then
            Error(CsvHeaderMissingErr);
        if LineNo = 0 then
            Error(NoLinesErr);

        TempBatch.Init();
        TempBatch."Message ID" := CopyStr(CheckLength(FirstRowValues.Get('messageid'), 'messageId', MaxStrLen(TempBatch."Message ID")), 1, MaxStrLen(TempBatch."Message ID"));
        TempBatch."Employer No." := CopyStr(CheckLength(FirstRowValues.Get('employerno'), 'employerNo', MaxStrLen(TempBatch."Employer No.")), 1, MaxStrLen(TempBatch."Employer No."));
        TempBatch.Period := CopyStr(CheckLength(FirstRowValues.Get('period'), 'period', MaxStrLen(TempBatch.Period)), 1, MaxStrLen(TempBatch.Period));
        TempBatch."Received Date" := ParseDate(FirstRowValues.Get('receiveddate'), 'receivedDate');
        TempBatch."Control Total" := ParseDecimal(FirstRowValues.Get('controltotal'), 'controlTotal', 0);
    end;

    local procedure ReadCsvHeader(HeaderText: Text; var Columns: Dictionary of [Text, Integer])
    var
        Names: List of [Text];
        Name: Text;
        Index: Integer;
    begin
        Names := SplitCsvRow(HeaderText);
        foreach Name in Names do begin
            Index += 1;
            Name := LowerCase(Name);
            if not Columns.ContainsKey(Name) then
                Columns.Add(Name, Index);
        end;
    end;

    /// <summary>
    /// Splits a CSV row on commas and trims each cell, including surrounding double quotes.
    /// Quoted cells that contain commas are not supported (see README).
    /// </summary>
    local procedure SplitCsvRow(RowText: Text) Cells: List of [Text]
    var
        RawCells: List of [Text];
        Cell: Text;
    begin
        RawCells := RowText.Split(',');
        foreach Cell in RawCells do
            Cells.Add(Cell.Trim().TrimStart('"').TrimEnd('"').Trim());
    end;

    local procedure GetJsonText(JObject: JsonObject; FieldName: Text; MaxLength: Integer): Text
    var
        Token: JsonToken;
    begin
        if not JObject.Get(FieldName, Token) then
            Error(MissingFieldErr, FieldName);
        if not Token.IsValue() then
            Error(MissingFieldErr, FieldName);
        if Token.AsValue().IsNull() then
            Error(MissingFieldErr, FieldName);
        exit(CheckLength(JsonValueToText(Token.AsValue()), FieldName, MaxLength));
    end;

    local procedure GetJsonLineText(JObject: JsonObject; FieldName: Text; LineNo: Integer; MaxLength: Integer): Text
    var
        Token: JsonToken;
    begin
        if not JObject.Get(FieldName, Token) then
            Error(MissingLineFieldErr, LineNo, FieldName);
        if not Token.IsValue() then
            Error(MissingLineFieldErr, LineNo, FieldName);
        if Token.AsValue().IsNull() then
            Error(MissingLineFieldErr, LineNo, FieldName);
        exit(CheckLength(JsonValueToText(Token.AsValue()), FieldName, MaxLength));
    end;

    /// <summary>
    /// Text of a JSON value. A JSON string is unescaped; a number keeps its JSON form
    /// (for example 6000.00), so it parses the same way whatever the server's culture.
    /// </summary>
    local procedure JsonValueToText(Value: JsonValue): Text
    var
        RawText: Text;
    begin
        Value.WriteTo(RawText);
        if RawText.StartsWith('"') then
            exit(Value.AsText());
        exit(RawText);
    end;

    local procedure CheckLength(Value: Text; FieldName: Text; MaxLength: Integer): Text
    begin
        if StrLen(Value) > MaxLength then
            Error(ValueTooLongErr, FieldName, MaxLength);
        exit(Value);
    end;

    /// <summary>
    /// Parses a number in invariant (XML) format, so 6000.00 reads the same in every client language.
    /// LineNo = 0 means a header field.
    /// </summary>
    local procedure ParseDecimal(Value: Text; FieldName: Text; LineNo: Integer) Result: Decimal
    begin
        if not Evaluate(Result, Value, 9) then
            if LineNo = 0 then
                Error(InvalidNumberErr, FieldName, Value)
            else
                Error(InvalidLineNumberErr, LineNo, FieldName, Value);
    end;

    local procedure ParseDate(Value: Text; FieldName: Text) Result: Date
    begin
        if not Evaluate(Result, Value, 9) then
            Error(InvalidDateErr, FieldName, Value);
    end;

    local procedure StripBom(Value: Text): Text
    var
        BomChar: Char;
    begin
        BomChar := 65279;
        exit(DelChr(Value, '<', Format(BomChar)));
    end;

    local procedure GetFileExtension(FileName: Text): Text
    var
        DotPosition: Integer;
    begin
        DotPosition := FileName.LastIndexOf('.');
        if DotPosition = 0 then
            exit('');
        exit(LowerCase(FileName.Substring(DotPosition + 1)));
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeReceiveBatch(var TempBatch: Record "PEN Contribution Batch" temporary; var TempLine: Record "PEN Intake Line Buffer" temporary)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterReceiveBatch(var Batch: Record "PEN Contribution Batch")
    begin
    end;
}
