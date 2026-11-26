namespace Zamara.Pension;

using Microsoft.Bank.BankAccount;
using Microsoft.Foundation.NoSeries;
using Microsoft.Sales.Customer;

table 50100 "PEN Pension Setup"
{
    Caption = 'Pension Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            AllowInCustomizations = Never;
        }
        field(10; "Member Nos."; Code[20])
        {
            Caption = 'Member Nos.';
            TableRelation = "No. Series";
        }
        field(11; "Employer Nos."; Code[20])
        {
            Caption = 'Employer Nos.';
            TableRelation = "No. Series";
        }
        field(12; "Contribution Batch Nos."; Code[20])
        {
            Caption = 'Contribution Batch Nos.';
            TableRelation = "No. Series";
        }
        field(13; "Receipt Nos."; Code[20])
        {
            Caption = 'Receipt Nos.';
            TableRelation = "No. Series";
        }
        field(14; "Posted Receipt Nos."; Code[20])
        {
            Caption = 'Posted Receipt Nos.';
            TableRelation = "No. Series";
        }
        field(20; "Remittance Due Day"; Integer)
        {
            Caption = 'Remittance Due Day';
            InitValue = 9;
            MinValue = 1;
            MaxValue = 31;
        }
        field(21; "Late Penalty %"; Decimal)
        {
            Caption = 'Late Penalty %';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;
        }
        field(30; "Queue Batch Size"; Integer)
        {
            Caption = 'Queue Batch Size';
            InitValue = 500;
            MinValue = 1;
        }
        field(31; "Max Retry Attempts"; Integer)
        {
            Caption = 'Max Retry Attempts';
            InitValue = 3;
            MinValue = 0;
        }
        field(40; "Default Bank Account No."; Code[20])
        {
            Caption = 'Default Bank Account No.';
            TableRelation = "Bank Account";
        }
        // Cue FlowFields used by the Queue Monitor page.
        field(100; "Pending Lines"; Integer)
        {
            Caption = 'Pending';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const(Pending)));
            Editable = false;
        }
        field(101; "Processing Lines"; Integer)
        {
            Caption = 'Processing';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const(Processing)));
            Editable = false;
        }
        field(102; "Posted Lines"; Integer)
        {
            Caption = 'Posted';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const(Posted)));
            Editable = false;
        }
        field(103; "Failed Lines"; Integer)
        {
            Caption = 'Failed';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const(Failed)));
            Editable = false;
        }
        field(104; "Dead Letter Lines"; Integer)
        {
            Caption = 'Dead Letter';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Queue" where(Status = const("Dead Letter")));
            Editable = false;
        }
        field(105; "Open Batches"; Integer)
        {
            Caption = 'Open Batches';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Batch" where(Status = filter(Received | "In Progress")));
            Editable = false;
        }
        field(106; "Open Receipts"; Integer)
        {
            Caption = 'Unposted Receipts';
            FieldClass = FlowField;
            CalcFormula = count("PEN Receipt Header");
            Editable = false;
        }
        field(107; "Active Members"; Integer)
        {
            Caption = 'Active Members';
            FieldClass = FlowField;
            CalcFormula = count("PEN Member" where(Status = const(Active)));
            Editable = false;
        }
        field(108; "Pension Employers"; Integer)
        {
            Caption = 'Employers';
            FieldClass = FlowField;
            CalcFormula = count(Customer where("PEN Pension Employer" = const(true)));
            Editable = false;
        }
        field(109; "Suspended Employers"; Integer)
        {
            Caption = 'Suspended Employers';
            FieldClass = FlowField;
            CalcFormula = count(Customer where("PEN Pension Employer" = const(true), "PEN Employer Status" = const(Suspended)));
            Editable = false;
        }
        field(110; "Batches with Errors"; Integer)
        {
            Caption = 'Batches with Errors';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Batch" where(Status = const("Completed with Errors")));
            Editable = false;
        }
        field(111; "Late Batches"; Integer)
        {
            Caption = 'Late Batches (Penalised)';
            FieldClass = FlowField;
            CalcFormula = count("PEN Contribution Batch" where("Penalty Posted" = const(true)));
            Editable = false;
        }
        field(112; "Schemes"; Integer)
        {
            Caption = 'Schemes';
            FieldClass = FlowField;
            CalcFormula = count("PEN Scheme");
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

   
    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;
}
