namespace Zamara.Pension;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.Receivables;

page 50107 "PEN Contribution Batch"
{
    Caption = 'Contribution Batch';
    PageType = Document;
    SourceTable = "PEN Contribution Batch";
    UsageCategory = None;
    ApplicationArea = All;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.") { ToolTip = 'Specifies the batch number. It is also the document number of the employer invoice, the G/L entries and the member ledger entries.'; }
                field("Message ID"; Rec."Message ID") { ToolTip = 'Specifies the employer''s message ID.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer that sent the batch.'; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field(Period; Rec.Period) { ToolTip = 'Specifies the contribution period.'; }
                field("Received Date"; Rec."Received Date") { ToolTip = 'Specifies the date the employer remitted the batch.'; }
                field("Due Date"; Rec."Due Date") { ToolTip = 'Specifies the date the batch was due. A batch received after this date is charged a late penalty.'; }
                field(Status; Rec.Status) { ToolTip = 'Specifies the processing status of the batch.'; }
                field(Source; Rec.Source) { ToolTip = 'Specifies how the batch was received.'; }
                field("Received By"; Rec."Received By") { ToolTip = 'Specifies who received the batch.'; }
                field("Received At"; Rec."Received At") { ToolTip = 'Specifies when the batch was received.'; }
            }
            group(Totals)
            {
                Caption = 'Totals';
                field("Control Total"; Rec."Control Total") { ToolTip = 'Specifies the control total from the file.'; }
                field("No. of Lines"; Rec."No. of Lines") { ToolTip = 'Specifies the number of member lines.'; }
                field("Posted Amount"; Rec."Posted Amount") { ToolTip = 'Specifies the total of posted lines.'; }
                field("Member Ledger Amount"; Rec."Member Ledger Amount") { ToolTip = 'Specifies the total of member ledger entries for this batch.'; }
                field("Invoiced Amount"; Rec."Invoiced Amount") { ToolTip = 'Specifies the contributions invoiced to the employer for this batch.'; }
                field(Outstanding; OutstandingAmount)
                {
                    Caption = 'Outstanding (Employer)';
                    ToolTip = 'Specifies how much of this batch''s invoices (contributions and penalty) the employer still owes.';
                    AutoFormatType = 1;
                    Editable = false;
                }
                field("Penalty Posted"; Rec."Penalty Posted") { ToolTip = 'Specifies that a late remittance penalty has been invoiced.'; }
                field("Penalty Amount"; Rec."Penalty Amount") { ToolTip = 'Specifies the late remittance penalty invoiced.'; }
            }
            group(LineStatus)
            {
                Caption = 'Line Status';
                field("Pending Lines"; Rec."Pending Lines") { ToolTip = 'Specifies the number of lines waiting to be processed.'; }
                field("Processing Lines"; Rec."Processing Lines") { ToolTip = 'Specifies the number of lines being processed right now.'; }
                field("Posted Lines"; Rec."Posted Lines") { ToolTip = 'Specifies the number of posted lines.'; }
                field("Failed Lines"; Rec."Failed Lines") { ToolTip = 'Specifies the number of failed lines that will be retried.'; Style = Attention; }
                field("Dead Letter Lines"; Rec."Dead Letter Lines") { ToolTip = 'Specifies the number of lines that need a manual Reprocess.'; Style = Unfavorable; }
            }
            part(Lines; "PEN Contribution Queue Subform")
            {
                Caption = 'Lines';
                SubPageLink = "Batch No." = field("No.");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProcessNow)
            {
                Caption = 'Process Batch Now';
                ToolTip = 'Processes this batch''s Pending lines now, in this session.';
                Image = Start;

                trigger OnAction()
                var
                    QueueProcessor: Codeunit "PEN Queue Processor";
                begin
                    QueueProcessor.SetBatchFilter(Rec."No.");
                    QueueProcessor.ProcessPending();
                    CurrPage.Update(false);
                end;
            }
            action(CheckReconciliation)
            {
                Caption = 'Check Reconciliation';
                ToolTip = 'Checks that the member ledger total equals the employer invoice and the G/L credit to Member Liability for this batch.';
                Image = Reconcile;

                trigger OnAction()
                var
                    PensionMgt: Codeunit "PEN Pension Mgt";
                begin
                    PensionMgt.CheckReconciliation(Rec, true);
                end;
            }
        }
        area(Navigation)
        {
            action(MemberLedgerEntries)
            {
                Caption = 'Member Ledger Entries';
                ToolTip = 'Shows the member ledger entries posted from this batch.';
                Image = LedgerEntries;
                RunObject = page "PEN Member Ledger Entries";
                RunPageLink = "Batch No." = field("No.");
            }
            action(EmployerEntries)
            {
                Caption = 'Employer Ledger Entries';
                ToolTip = 'Shows the employer''s invoices and payments for this batch.';
                Image = CustomerLedger;

                trigger OnAction()
                var
                    CustLedgerEntry: Record "Cust. Ledger Entry";
                begin
                    CustLedgerEntry.SetRange("Customer No.", Rec."Employer No.");
                    CustLedgerEntry.SetFilter("Document No.", '%1|%2', Rec."No.", Rec.GetPenaltyDocumentNo());
                    Page.Run(Page::"Customer Ledger Entries", CustLedgerEntry);
                end;
            }
            action(GLEntries)
            {
                Caption = 'G/L Entries';
                ToolTip = 'Shows the G/L entries posted for this batch, including the penalty.';
                Image = GLRegisters;

                trigger OnAction()
                var
                    GLEntry: Record "G/L Entry";
                begin
                    GLEntry.SetFilter("Document No.", '%1|%2', Rec."No.", Rec.GetPenaltyDocumentNo());
                    Page.Run(Page::"General Ledger Entries", GLEntry);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(ProcessNow_Promoted; ProcessNow) { }
                actionref(CheckReconciliation_Promoted; CheckReconciliation) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Entries';
                actionref(MemberLedgerEntries_Promoted; MemberLedgerEntries) { }
                actionref(EmployerEntries_Promoted; EmployerEntries) { }
                actionref(GLEntries_Promoted; GLEntries) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        OutstandingAmount := Rec.GetOutstandingAmount();
    end;

    var
        OutstandingAmount: Decimal;
}
