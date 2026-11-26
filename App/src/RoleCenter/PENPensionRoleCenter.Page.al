namespace Zamara.Pension;

using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;
using System.Threading;

/// <summary>
/// Role center for the pension administrator: queue and receivable cues, recent batches,
/// the most common processing errors, and navigation to every pension page.
/// </summary>
page 50122 "PEN Pension Role Center"
{
    Caption = 'Pension Administrator';
    PageType = RoleCenter;
    ApplicationArea = All;

    layout
    {
        area(RoleCenter)
        {
            part(Activities; "PEN Pension Activities")
            {
                ApplicationArea = All;
            }
            part(RecentBatches; "PEN Recent Batches Part")
            {
                ApplicationArea = All;
            }
            part(TopErrors; "PEN Top Errors Part")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Embedding)
        {
            action(EmbeddedEmployers)
            {
                Caption = 'Employers';
                ToolTip = 'Opens the list of pension employers.';
                RunObject = page "PEN Employer List";
            }
            action(EmbeddedMembers)
            {
                Caption = 'Members';
                ToolTip = 'Opens the list of members.';
                RunObject = page "PEN Member List";
            }
            action(EmbeddedBatches)
            {
                Caption = 'Contribution Batches';
                ToolTip = 'Opens the received contribution batches.';
                RunObject = page "PEN Contribution Batches";
            }
            action(EmbeddedQueue)
            {
                Caption = 'Contribution Queue';
                ToolTip = 'Opens every contribution line with its processing status.';
                RunObject = page "PEN Contribution Queue";
            }
            action(EmbeddedReceipts)
            {
                Caption = 'Receipts';
                ToolTip = 'Opens the unposted employer receipts.';
                RunObject = page "PEN Receipts";
            }
            action(EmbeddedMemberLedger)
            {
                Caption = 'Member Ledger Entries';
                ToolTip = 'Opens the member ledger.';
                RunObject = page "PEN Member Ledger Entries";
            }
        }
        area(Sections)
        {
            group(Contributions)
            {
                Caption = 'Contributions';
                Image = Journals;
                action(Batches)
                {
                    Caption = 'Contribution Batches';
                    ToolTip = 'Opens the received contribution batches.';
                    RunObject = page "PEN Contribution Batches";
                }
                action(QueueLines)
                {
                    Caption = 'Contribution Queue';
                    ToolTip = 'Opens every contribution line with its processing status.';
                    RunObject = page "PEN Contribution Queue";
                }
                action(FailedLines)
                {
                    Caption = 'Failed Lines';
                    ToolTip = 'Opens the lines that failed and will be retried.';
                    RunObject = page "PEN Contribution Queue";
                    RunPageView = where(Status = const(Failed));
                }
                action(DeadLetterLines)
                {
                    Caption = 'Dead Letter Lines';
                    ToolTip = 'Opens the lines that need a manual Reprocess.';
                    RunObject = page "PEN Contribution Queue";
                    RunPageView = where(Status = const("Dead Letter"));
                }
                action(QueueMonitor)
                {
                    Caption = 'Queue Monitor';
                    ToolTip = 'Opens the queue monitor: counts by status, last run and most common errors.';
                    RunObject = page "PEN Queue Monitor";
                }
                action(RunLog)
                {
                    Caption = 'Queue Run Log';
                    ToolTip = 'Opens the log of processor runs.';
                    RunObject = page "PEN Queue Run Log";
                }
            }
            group(Receivables)
            {
                Caption = 'Employer Receivables';
                Image = Receivables;
                action(Employers)
                {
                    Caption = 'Employers';
                    ToolTip = 'Opens the list of pension employers.';
                    RunObject = page "PEN Employer List";
                }
                action(Receipts)
                {
                    Caption = 'Receipts';
                    ToolTip = 'Opens the unposted employer receipts.';
                    RunObject = page "PEN Receipts";
                }
                action(PostedReceipts)
                {
                    Caption = 'Posted Receipts';
                    ToolTip = 'Opens the posted employer receipts.';
                    RunObject = page "PEN Posted Receipts";
                }
                action(EmployerLedgerEntries)
                {
                    Caption = 'Employer Ledger Entries';
                    ToolTip = 'Opens the customer ledger entries: contribution invoices, penalties and receipts.';
                    RunObject = page "Customer Ledger Entries";
                }
            }
            group(Membership)
            {
                Caption = 'Membership';
                Image = HumanResources;
                action(Members)
                {
                    Caption = 'Members';
                    ToolTip = 'Opens the list of members.';
                    RunObject = page "PEN Member List";
                }
                action(MemberLedgerEntries)
                {
                    Caption = 'Member Ledger Entries';
                    ToolTip = 'Opens the member ledger.';
                    RunObject = page "PEN Member Ledger Entries";
                }
                action(SchemesList)
                {
                    Caption = 'Schemes';
                    ToolTip = 'Opens the list of pension schemes.';
                    RunObject = page "PEN Schemes";
                }
            }
            group(SetupGroup)
            {
                Caption = 'Setup';
                Image = Setup;
                action(PensionSetup)
                {
                    Caption = 'Pension Setup';
                    ToolTip = 'Opens the pension setup: number series, remittance rules and processing settings.';
                    RunObject = page "PEN Pension Setup";
                }
                action(JobQueueEntries)
                {
                    Caption = 'Job Queue Entries';
                    ToolTip = 'Opens the Job Queue entries, including the contribution processor.';
                    RunObject = page "Job Queue Entries";
                }
                action(GenerateTestDataSection)
                {
                    Caption = 'Generate Test Data';
                    ToolTip = 'Creates a scheme, employers, members and contribution batches for testing.';
                    RunObject = page "PEN Generate Test Data";
                }
            }
        }
        area(Creation)
        {
            action(NewMember)
            {
                Caption = 'Member';
                ToolTip = 'Registers a new member.';
                Image = Employee;
                RunObject = page "PEN Member Card";
                RunPageMode = Create;
            }
            action(NewEmployer)
            {
                Caption = 'Employer';
                ToolTip = 'Registers a new pension employer.';
                Image = NewCustomer;
                RunObject = page "PEN Employer Card";
                RunPageMode = Create;
            }
            action(NewReceipt)
            {
                Caption = 'Receipt';
                ToolTip = 'Records money received from an employer.';
                Image = CashReceiptJournal;
                RunObject = page "PEN Receipt";
                RunPageMode = Create;
            }
        }
        area(Processing)
        {
            action(ImportFile)
            {
                Caption = 'Import Contribution File';
                ToolTip = 'Uploads a contribution batch as a JSON or CSV file.';
                Image = Import;
                RunObject = codeunit "PEN Import Contribution File";
            }
            action(ProcessInBackground)
            {
                Caption = 'Process Queue in Background';
                ToolTip = 'Starts a one-off Job Queue entry that processes all Pending lines.';
                Image = ExecuteBatch;
                RunObject = codeunit "PEN Schedule Queue Run";
            }
            action(GenerateTestData)
            {
                Caption = 'Generate Test Data';
                ToolTip = 'Creates a scheme, employers, members and contribution batches for testing.';
                Image = CreateDocuments;
                RunObject = page "PEN Generate Test Data";
            }
        }
        area(Reporting)
        {
            action(MemberStatement)
            {
                Caption = 'Member Statement';
                ToolTip = 'Prints statements for one or more members over a date range.';
                Image = Report;
                RunObject = report "PEN Member Statement";
            }
            action(EmployerStatement)
            {
                Caption = 'Employer Statement';
                ToolTip = 'Prints the standard customer statement for employers.';
                Image = Report;
                RunObject = report "Customer Statement";
            }
        }
    }
}
