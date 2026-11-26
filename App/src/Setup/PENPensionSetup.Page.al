namespace Zamara.Pension;

page 50100 "PEN Pension Setup"
{
    Caption = 'Pension Setup';
    PageType = Card;
    SourceTable = "PEN Pension Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Numbering)
            {
                Caption = 'Numbering';
                field("Member Nos."; Rec."Member Nos.") { ToolTip = 'Specifies the number series for members.'; }
                field("Employer Nos."; Rec."Employer Nos.") { ToolTip = 'Specifies the number series for pension employers (created as customers).'; }
                field("Contribution Batch Nos."; Rec."Contribution Batch Nos.") { ToolTip = 'Specifies the number series for received contribution batches.'; }
                field("Receipt Nos."; Rec."Receipt Nos.") { ToolTip = 'Specifies the number series for employer receipts.'; }
                field("Posted Receipt Nos."; Rec."Posted Receipt Nos.") { ToolTip = 'Specifies the number series for posted receipts. If blank, the receipt keeps its own number.'; }
            }
            group(Remittance)
            {
                Caption = 'Remittance';
                field("Remittance Due Day"; Rec."Remittance Due Day") { ToolTip = 'Specifies the day of the month after the contribution period by which contributions are due.'; }
                field("Late Penalty %"; Rec."Late Penalty %") { ToolTip = 'Specifies the penalty, as a percentage of the batch control total, charged to the employer when a batch is received after the due date.'; }
                field("Default Bank Account No."; Rec."Default Bank Account No.") { ToolTip = 'Specifies the bank account that new receipts use by default.'; }
            }
            group(Processing)
            {
                Caption = 'Background Processing';
                field("Queue Batch Size"; Rec."Queue Batch Size") { ToolTip = 'Specifies how many queue lines are processed in each transaction (one commit per chunk).'; }
                field("Max Retry Attempts"; Rec."Max Retry Attempts") { ToolTip = 'Specifies how many times a failed line is retried before it moves to Dead Letter.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateJobQueueEntry)
            {
                Caption = 'Create Job Queue Entry';
                ToolTip = 'Creates a recurring Job Queue entry that processes the contribution queue every minute. Create it twice to demonstrate parallel processing.';
                Image = Job;

                trigger OnAction()
                var
                    PensionMgt: Codeunit "PEN Pension Mgt";
                begin
                    PensionMgt.CreateJobQueueEntry(true);
                    Message(JobQueueCreatedMsg);
                end;
            }
            action(ProcessInBackground)
            {
                Caption = 'Process Queue in Background';
                ToolTip = 'Starts a one-off Job Queue entry that processes all Pending lines in the background, so you can keep working.';
                Image = ExecuteBatch;

                trigger OnAction()
                var
                    PensionMgt: Codeunit "PEN Pension Mgt";
                begin
                    PensionMgt.CreateJobQueueEntry(false);
                    Message(BackgroundStartedMsg);
                end;
            }
            action(ProcessNow)
            {
                Caption = 'Process Queue Now';
                ToolTip = 'Processes all Pending lines now, in this session. Useful for demonstrations and troubleshooting.';
                Image = Start;

                trigger OnAction()
                var
                    QueueProcessor: Codeunit "PEN Queue Processor";
                    LinesProcessed: Integer;
                begin
                    LinesProcessed := QueueProcessor.ProcessPending();
                    Message(ProcessedMsg, LinesProcessed);
                end;
            }
            action(GenerateTestData)
            {
                Caption = 'Generate Test Data';
                ToolTip = 'Creates a scheme, employers, members and one contribution batch per employer for a chosen period.';
                Image = CreateDocuments;
                RunObject = page "PEN Generate Test Data";
            }
            action(GenerateReceipts)
            {
                Caption = 'Generate Receipts';
                ToolTip = 'Creates and posts receipts for processed batches: about 70% paid in full, 20% paid half and 10% left unpaid.';
                Image = CashReceiptJournal;

                trigger OnAction()
                var
                    TestDataGenerator: Codeunit "PEN Test Data Generator";
                begin
                    Message(TestDataGenerator.GenerateReceipts());
                end;
            }
        }
        area(Navigation)
        {
            action(Monitor)
            {
                Caption = 'Queue Monitor';
                ToolTip = 'Shows the queue by status, the last runs and the most common errors.';
                Image = Statistics;
                RunObject = page "PEN Queue Monitor";
            }
            action(Schemes)
            {
                Caption = 'Schemes';
                ToolTip = 'Opens the list of pension schemes.';
                Image = SetupList;
                RunObject = page "PEN Schemes";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(ProcessNow_Promoted; ProcessNow) { }
                actionref(ProcessInBackground_Promoted; ProcessInBackground) { }
                actionref(CreateJobQueueEntry_Promoted; CreateJobQueueEntry) { }
                actionref(GenerateTestData_Promoted; GenerateTestData) { }
                actionref(Monitor_Promoted; Monitor) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        Rec.GetSetup();
    end;

    var
        JobQueueCreatedMsg: Label 'A recurring Job Queue entry has been created. It processes the contribution queue every minute.';
        BackgroundStartedMsg: Label 'Processing has been scheduled in the background. Check the Queue Monitor for progress.';
        ProcessedMsg: Label '%1 lines were processed.', Comment = '%1 = number of lines';
}
