namespace Zamara.Pension;

using Microsoft.Foundation.NoSeries;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;

/// <summary>
/// Header of one employer's monthly contribution schedule, as received.
/// </summary>
table 50104 "PEN Contribution Batch"
{
    Caption = 'Contribution Batch';
    DataClassification = CustomerContent;
    DrillDownPageId = "PEN Contribution Batches";
    LookupPageId = "PEN Contribution Batches";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            Editable = false;
        }
        field(2; "Message ID"; Text[100])
        {
            Caption = 'Message ID';
            Editable = false;
        }
        field(3; "Employer No."; Code[20])
        {
            Caption = 'Employer No.';
            TableRelation = Customer;
            ValidateTableRelation = false;
            Editable = false;
        }
        field(4; "Employer Name"; Text[100])
        {
            Caption = 'Employer Name';
            FieldClass = FlowField;
            CalcFormula = lookup(Customer.Name where("No." = field("Employer No.")));
            Editable = false;
        }
        field(5; Period; Code[7])
        {
            Caption = 'Period';
            Editable = false;
        }
        field(6; "Received Date"; Date)
        {
            Caption = 'Received Date';
            Editable = false;
        }
        field(7; "Control Total"; Decimal)
        {
            Caption = 'Control Total';
            AutoFormatType = 1;
            Editable = false;
        }
        field(8; "Line Total"; Decimal)
        {
            Caption = 'Line Total';
            AutoFormatType = 1;
            Editable = false;
        }
        field(9; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            Editable = false;
        }
        field(10; Source; Enum "PEN Intake Source")
        {
            Caption = 'Source';
            Editable = false;
        }
        field(11; "Received By"; Code[50])
        {
            Caption = 'Received By';
            Editable = false;
            DataClassification = EndUserIdentifiableInformation;
        }
        field(12; "Received At"; DateTime)
        {
            Caption = 'Received At';
            Editable = false;
        }
        field(13; Status; Enum "PEN Batch Status")
        {
            Caption = 'Status';
            Editable = false;
        }
        field(14; "Due Date"; Date)
        {
            Caption = 'Remittance Due Date';
            Editable = false;
        }
        field(15; "Penalty Posted"; Boolean)
        {
            Caption = 'Penalty Posted';
            Editable = false;
        }
        field(16; "Penalty Amount"; Decimal)
        {
            Caption = 'Penalty Amount';
            AutoFormatType = 1;
            Editable = false;
        }
        field(17; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            TableRelation = "No. Series";
            Editable = false;
        }
        field(30; "Pending Lines"; Integer)
        {
            Caption = 'Pending';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Pending)));
            Editable = false;
        }
        field(31; "Processing Lines"; Integer)
        {
            Caption = 'Processing';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Processing)));
            Editable = false;
        }
        field(32; "Posted Lines"; Integer)
        {
            Caption = 'Posted';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Posted)));
            Editable = false;
        }
        field(33; "Failed Lines"; Integer)
        {
            Caption = 'Failed';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const(Failed)));
            Editable = false;
        }
        field(34; "Dead Letter Lines"; Integer)
        {
            Caption = 'Dead Letter';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where("Batch No." = field("No."), Status = const("Dead Letter")));
            Editable = false;
        }
        field(35; "Posted Amount"; Decimal)
        {
            Caption = 'Posted Amount';
            AutoFormatType = 1;
            FieldClass = FlowField;
            CalcFormula = sum("PEN Contribution Queue"."Line Amount" where("Batch No." = field("No."), Status = const(Posted)));
            Editable = false;
        }
        field(36; "Member Ledger Amount"; Decimal)
        {
            Caption = 'Member Ledger Amount';
            AutoFormatType = 1;
            FieldClass = FlowField;
            CalcFormula = sum("PEN Member Ledger Entry".Amount where("Batch No." = field("No.")));
            Editable = false;
        }
        field(37; "Invoiced Amount"; Decimal)
        {
            Caption = 'Invoiced Contributions';
            AutoFormatType = 1;
            FieldClass = FlowField;
            CalcFormula = sum("Detailed Cust. Ledg. Entry".Amount where("Customer No." = field("Employer No."),
                                                                        "Document No." = field("No."),
                                                                        "Document Type" = const(Invoice),
                                                                        "Entry Type" = const("Initial Entry")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(MessageID; "Message ID")
        {
            Unique = true;
        }
        key(EmployerPeriod; "Employer No.", Period) { }
        key(Status; Status) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Employer No.", Period, "Control Total", Status) { }
    }

    trigger OnDelete()
    var
        ContributionQueue: Record "PEN Contribution Queue";
    begin
        ContributionQueue.SetRange("Batch No.", "No.");
        ContributionQueue.SetFilter(Status, '%1|%2', ContributionQueue.Status::Posted, ContributionQueue.Status::Processing);
        if not ContributionQueue.IsEmpty() then
            Error(BatchHasPostedLinesErr, "No.");
        ContributionQueue.SetRange(Status);
        ContributionQueue.DeleteAll();
    end;

    var
        BatchHasPostedLinesErr: Label 'Batch %1 has posted or in-process lines and cannot be deleted.', Comment = '%1 = batch no.';
        PenaltyDocSuffixTxt: Label '-P', Locked = true;

    /// <summary>
    /// Document No. used for the late penalty invoice of this batch.
    /// </summary>
    procedure GetPenaltyDocumentNo(): Code[20]
    begin
        exit(CopyStr("No." + PenaltyDocSuffixTxt, 1, 20));
    end;

    /// <summary>
    /// Sum of the remaining amount on the employer's open invoices for this batch
    /// (contributions and penalty).
    /// </summary>
    procedure GetOutstandingAmount() Outstanding: Decimal
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
    begin
        FilterOpenInvoices(CustLedgerEntry);
        CustLedgerEntry.SetAutoCalcFields("Remaining Amount");
        if CustLedgerEntry.FindSet() then
            repeat
                Outstanding += CustLedgerEntry."Remaining Amount";
            until CustLedgerEntry.Next() = 0;
    end;

    /// <summary>
    /// Filters the employer's open, positive ledger entries that belong to this batch.
    /// </summary>
    procedure FilterOpenInvoices(var CustLedgerEntry: Record "Cust. Ledger Entry")
    begin
        CustLedgerEntry.Reset();
        CustLedgerEntry.SetRange("Customer No.", "Employer No.");
        CustLedgerEntry.SetFilter("Document No.", '%1|%2', "No.", GetPenaltyDocumentNo());
        CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::Invoice);
        CustLedgerEntry.SetRange(Open, true);
    end;

    /// <summary>
    /// Recalculates the batch status from its line statuses.
    /// </summary>
    procedure UpdateStatus()
    begin
        CalcFields("Pending Lines", "Processing Lines", "Posted Lines", "Failed Lines", "Dead Letter Lines");
        case true of
            ("Pending Lines" + "Processing Lines" + "Failed Lines" + "Dead Letter Lines" = 0) and ("Posted Lines" > 0):
                Status := Status::Posted;
            ("Pending Lines" + "Processing Lines" + "Failed Lines" = 0) and ("Dead Letter Lines" > 0):
                Status := Status::"Completed with Errors";
            "Posted Lines" + "Failed Lines" + "Dead Letter Lines" + "Processing Lines" > 0:
                Status := Status::"In Progress";
            else
                Status := Status::Received;
        end;
    end;
}
