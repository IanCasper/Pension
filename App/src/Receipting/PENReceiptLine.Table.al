namespace Zamara.Pension;

/// <summary>
/// Allocation of a receipt to one contribution batch. A blank Batch No. is a payment on account.
/// </summary>
table 50112 "PEN Receipt Line"
{
    Caption = 'Pension Receipt Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Receipt No."; Code[20])
        {
            Caption = 'Receipt No.';
            TableRelation = "PEN Receipt Header";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            Editable = false;
        }
        field(4; "Batch No."; Code[20])
        {
            Caption = 'Batch No.';
            TableRelation = "PEN Contribution Batch" where("Employer No." = field("Employer No."));

            trigger OnValidate()
            var
                Batch: Record "PEN Contribution Batch";
            begin
                if "Batch No." = '' then begin
                    "Outstanding Amount" := 0;
                    Description := OnAccountTxt;
                    exit;
                end;
                Batch.Get("Batch No.");
                Batch.TestField("Employer No.", "Employer No.");
                "Outstanding Amount" := Batch.GetOutstandingAmount();
                Description := CopyStr(StrSubstNo(BatchDescriptionTxt, Batch.Period, Batch."Message ID"), 1, MaxStrLen(Description));
                Validate(Amount, "Outstanding Amount");
            end;
        }
        field(5; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(6; "Outstanding Amount"; Decimal)
        {
            Caption = 'Outstanding Amount';
            AutoFormatType = 1;
            Editable = false;
        }
        field(7; Amount; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
            MinValue = 0;

            trigger OnValidate()
            begin
                if ("Batch No." <> '') and (Amount > "Outstanding Amount") then
                    Error(AmountExceedsOutstandingErr, Amount, "Outstanding Amount", "Batch No.");
            end;
        }
    }

    keys
    {
        key(PK; "Receipt No.", "Line No.")
        {
            Clustered = true;
            SumIndexFields = Amount;
        }
        key(Batch; "Batch No.") { }
    }

    trigger OnInsert()
    var
        ReceiptHeader: Record "PEN Receipt Header";
    begin
        ReceiptHeader.Get("Receipt No.");
        ReceiptHeader.TestField("Employer No.");
        "Employer No." := ReceiptHeader."Employer No.";
    end;

    var
        OnAccountTxt: Label 'Payment on account';
        BatchDescriptionTxt: Label 'Contributions %1 (%2)', Comment = '%1 = period, %2 = message ID';
        AmountExceedsOutstandingErr: Label 'Amount %1 is more than the outstanding amount %2 on batch %3.', Comment = '%1 = amount, %2 = outstanding, %3 = batch no.';

    procedure InitFromHeader(ReceiptHeader: Record "PEN Receipt Header")
    begin
        "Receipt No." := ReceiptHeader."No.";
        "Employer No." := ReceiptHeader."Employer No.";
    end;
}
