namespace Zamara.Pension;

using Microsoft.Bank.BankAccount;
using Microsoft.Sales.Customer;

table 50113 "PEN Posted Receipt Header"
{
    Caption = 'Posted Pension Receipt';
    DataClassification = CustomerContent;
    DrillDownPageId = "PEN Posted Receipts";
    LookupPageId = "PEN Posted Receipts";

    fields
    {
        field(1; "No."; Code[20]) { Caption = 'No.'; }
        field(2; "Employer No."; Code[20]) { Caption = 'Employer No.'; TableRelation = Customer; }
        field(3; "Employer Name"; Text[100]) { Caption = 'Employer Name'; }
        field(4; "Receipt Date"; Date) { Caption = 'Receipt Date'; }
        field(5; "Bank Account No."; Code[20]) { Caption = 'Bank Account No.'; TableRelation = "Bank Account"; }
        field(6; "Payment Reference"; Code[35]) { Caption = 'Payment Reference'; }
        field(7; Amount; Decimal) { Caption = 'Amount'; AutoFormatType = 1; }
        field(8; "Applied Amount"; Decimal) { Caption = 'Applied to Batches'; AutoFormatType = 1; }
        field(9; Description; Text[100]) { Caption = 'Description'; }
        field(10; "Pre-Assigned No."; Code[20]) { Caption = 'Receipt No. (Unposted)'; }
        field(11; "Posted By"; Code[50]) { Caption = 'Posted By'; DataClassification = EndUserIdentifiableInformation; }
        field(12; "Posted At"; DateTime) { Caption = 'Posted At'; }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(Employer; "Employer No.", "Receipt Date") { }
    }
}
