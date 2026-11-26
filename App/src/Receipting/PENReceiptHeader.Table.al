namespace Zamara.Pension;

using Microsoft.Bank.BankAccount;
using Microsoft.Foundation.NoSeries;
using Microsoft.Sales.Customer;

/// <summary>
/// Money received from an employer, before posting. Posting debits the bank and credits the
/// employer (customer), applying the payment to the open invoices of the batches on the lines.
/// </summary>
table 50102 "PEN Receipt Header"
{
    Caption = 'Pension Receipt';
    DataClassification = CustomerContent;
    DrillDownPageId = "PEN Receipts";
    LookupPageId = "PEN Receipts";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';

            trigger OnValidate()
            var
                NoSeries: Codeunit "No. Series";
            begin
                if "No." <> xRec."No." then begin
                    PensionSetup.GetSetup();
                    NoSeries.TestManual(PensionSetup."Receipt Nos.");
                    "No. Series" := '';
                end;
            end;
        }
        field(2; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            TableRelation = Customer where("PEN Pension Employer" = const(true));

            trigger OnValidate()
            var
                Employer: Record Customer;
                ReceiptLine: Record "PEN Receipt Line";
            begin
                if "Employer No." <> xRec."Employer No." then begin
                    ReceiptLine.SetRange("Receipt No.", "No.");
                    if not ReceiptLine.IsEmpty() then
                        Error(LinesExistErr, FieldCaption("Employer No."));
                end;
                if "Employer No." = '' then begin
                    "Employer Name" := '';
                    exit;
                end;
                Employer.Get("Employer No.");
                Employer.TestField("PEN Pension Employer", true);
                "Employer Name" := Employer.Name;
            end;
        }
        field(3; "Employer Name"; Text[100])
        {
            Caption = 'Employer Name';
            Editable = false;
        }
        field(4; "Receipt Date"; Date)
        {
            Caption = 'Receipt Date';
        }
        field(5; "Bank Account No."; Code[20])
        {
            Caption = 'Bank Account No.';
            TableRelation = "Bank Account";
        }
        field(6; "Payment Reference"; Code[35])
        {
            Caption = 'Payment Reference';
        }
        field(7; Amount; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
            MinValue = 0;
        }
        field(8; "Lines Total"; Decimal)
        {
            Caption = 'Lines Total';
            AutoFormatType = 1;
            FieldClass = FlowField;
            CalcFormula = sum("PEN Receipt Line".Amount where("Receipt No." = field("No.")));
            Editable = false;
        }
        field(9; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(10; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            TableRelation = "No. Series";
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(Employer; "Employer No.") { }
    }

    trigger OnInsert()
    var
        NoSeries: Codeunit "No. Series";
    begin
        PensionSetup.GetSetup();
        if "No." = '' then begin
            PensionSetup.TestField("Receipt Nos.");
            "No. Series" := PensionSetup."Receipt Nos.";
            "No." := NoSeries.GetNextNo("No. Series");
        end;
        if "Receipt Date" = 0D then
            "Receipt Date" := WorkDate();
        if "Bank Account No." = '' then
            "Bank Account No." := PensionSetup."Default Bank Account No.";
    end;

    trigger OnDelete()
    var
        ReceiptLine: Record "PEN Receipt Line";
    begin
        ReceiptLine.SetRange("Receipt No.", "No.");
        ReceiptLine.DeleteAll();
    end;

    var
        PensionSetup: Record "PEN Pension Setup";
        LinesExistErr: Label 'You cannot change %1 while the receipt has lines. Delete the lines first.', Comment = '%1 = field caption';

    procedure AssistEdit(OldReceipt: Record "PEN Receipt Header"): Boolean
    var
        Receipt: Record "PEN Receipt Header";
        NoSeries: Codeunit "No. Series";
    begin
        Receipt := Rec;
        PensionSetup.GetSetup();
        PensionSetup.TestField("Receipt Nos.");
        if NoSeries.LookupRelatedNoSeries(PensionSetup."Receipt Nos.", OldReceipt."No. Series", Receipt."No. Series") then begin
            Receipt."No." := NoSeries.GetNextNo(Receipt."No. Series");
            Rec := Receipt;
            exit(true);
        end;
    end;

    /// <summary>
    /// Adds one line per batch of this employer that still has an outstanding invoice amount.
    /// </summary>
    procedure SuggestLines()
    var
        Batch: Record "PEN Contribution Batch";
        ReceiptLine: Record "PEN Receipt Line";
        Outstanding: Decimal;
        LineNo: Integer;
    begin
        TestField("Employer No.");
        ReceiptLine.SetRange("Receipt No.", "No.");
        if ReceiptLine.FindLast() then
            LineNo := ReceiptLine."Line No.";
        Batch.SetCurrentKey("Employer No.", Period);
        Batch.SetRange("Employer No.", "Employer No.");
        if Batch.FindSet() then
            repeat
                ReceiptLine.SetRange("Batch No.", Batch."No.");
                if ReceiptLine.IsEmpty() then begin
                    Outstanding := Batch.GetOutstandingAmount();
                    if Outstanding > 0 then begin
                        LineNo += 10000;
                        ReceiptLine.Init();
                        ReceiptLine.InitFromHeader(Rec);
                        ReceiptLine."Line No." := LineNo;
                        ReceiptLine.Validate("Batch No.", Batch."No.");
                        ReceiptLine.Insert(true);
                    end;
                end;
            until Batch.Next() = 0;
    end;
}
