namespace Zamara.Pension;

page 50106 "PEN Contribution Batches"
{
    Caption = 'Contribution Batches';
    PageType = List;
    SourceTable = "PEN Contribution Batch";
    SourceTableView = sorting("No.") order(descending);
    CardPageId = "PEN Contribution Batch";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ToolTip = 'Specifies the batch number.'; }
                field("Message ID"; Rec."Message ID") { ToolTip = 'Specifies the employer''s message ID. A message ID can only be received once.'; }
                field("Employer No."; Rec."Employer No.") { ToolTip = 'Specifies the employer that sent the batch.'; }
                field("Employer Name"; Rec."Employer Name") { ToolTip = 'Specifies the employer name.'; }
                field(Period; Rec.Period) { ToolTip = 'Specifies the contribution period.'; }
                field("Received Date"; Rec."Received Date") { ToolTip = 'Specifies the date the employer remitted the batch.'; }
                field("Due Date"; Rec."Due Date") { ToolTip = 'Specifies the date the batch was due.'; }
                field("Control Total"; Rec."Control Total") { ToolTip = 'Specifies the control total from the file.'; }
                field("No. of Lines"; Rec."No. of Lines") { ToolTip = 'Specifies the number of member lines.'; }
                field(Status; Rec.Status) { ToolTip = 'Specifies the processing status of the batch.'; }
                field("Pending Lines"; Rec."Pending Lines") { ToolTip = 'Specifies the number of lines waiting to be processed.'; }
                field("Posted Lines"; Rec."Posted Lines") { ToolTip = 'Specifies the number of posted lines.'; }
                field("Failed Lines"; Rec."Failed Lines") { ToolTip = 'Specifies the number of failed lines that will be retried.'; Style = Attention; }
                field("Dead Letter Lines"; Rec."Dead Letter Lines") { ToolTip = 'Specifies the number of lines that failed too many times and need a manual Reprocess.'; Style = Unfavorable; }
                field("Penalty Posted"; Rec."Penalty Posted") { ToolTip = 'Specifies that a late remittance penalty has been invoiced.'; }
                field(Source; Rec.Source) { ToolTip = 'Specifies how the batch was received.'; }
                field("Received At"; Rec."Received At") { ToolTip = 'Specifies when the batch was received.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportFile)
            {
                Caption = 'Import File';
                ToolTip = 'Uploads a contribution batch as a JSON or CSV file. Only structural checks are run now; the lines are processed in the background.';
                Image = Import;

                trigger OnAction()
                var
                    ContributionIntake: Codeunit "PEN Contribution Intake";
                begin
                    ContributionIntake.ImportFromFile();
                    CurrPage.Update(false);
                end;
            }
            action(ProcessInBackground)
            {
                Caption = 'Process Queue in Background';
                ToolTip = 'Starts a one-off Job Queue entry that processes all Pending lines in the background.';
                Image = ExecuteBatch;

                trigger OnAction()
                var
                    PensionMgt: Codeunit "PEN Pension Mgt";
                begin
                    PensionMgt.CreateJobQueueEntry(false);
                    Message(BackgroundStartedMsg);
                end;
            }
        }
        area(Navigation)
        {
            action(QueueLines)
            {
                Caption = 'All Queue Lines';
                ToolTip = 'Shows every queue line across all batches.';
                Image = List;
                RunObject = page "PEN Contribution Queue";
            }
            action(Monitor)
            {
                Caption = 'Queue Monitor';
                ToolTip = 'Shows the queue by status, the last runs and the most common errors.';
                Image = Statistics;
                RunObject = page "PEN Queue Monitor";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(ImportFile_Promoted; ImportFile) { }
                actionref(ProcessInBackground_Promoted; ProcessInBackground) { }
                actionref(Monitor_Promoted; Monitor) { }
            }
        }
    }

    var
        BackgroundStartedMsg: Label 'Processing has been scheduled in the background. Check the Queue Monitor for progress.';
}
