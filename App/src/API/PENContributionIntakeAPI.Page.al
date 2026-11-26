namespace Zamara.Pension;

/// <summary>
/// API intake: POST /api/zamara/pensions/v1.0/companies({id})/contributionIntakes
/// with body {"payload": "&lt;the batch JSON as a string&gt;"}.
/// The payload goes through exactly the same codeunit as a file upload
/// ("PEN Contribution Intake".ReceiveBatch). A rejected batch returns HTTP 400 with the reason.
/// </summary>
page 50114 "PEN Contribution Intake API"
{
    PageType = API;
    Caption = 'contributionIntake', Locked = true;
    APIPublisher = 'zamara';
    APIGroup = 'pensions';
    APIVersion = 'v1.0';
    EntityName = 'contributionIntake';
    EntitySetName = 'contributionIntakes';
    SourceTable = "PEN API Intake Request";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Extensible = false;

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'id', Locked = true;
                    Editable = false;
                }
                field(payload; PayloadText)
                {
                    Caption = 'payload', Locked = true;

                    trigger OnValidate()
                    var
                        ContributionIntake: Codeunit "PEN Contribution Intake";
                    begin
                        // The intake runs here, not in OnInsertRecord: payload is a page variable, so a POST
                        // that sets only payload leaves Rec unchanged and the platform skips the insert
                        // (and OnInsertRecord) entirely. Filling Rec here makes the platform insert it.
                        ContributionIntake.ReceiveFromApi(Rec, PayloadText);
                    end;
                }
                field(messageId; Rec."Message ID")
                {
                    Caption = 'messageId', Locked = true;
                    Editable = false;
                }
                field(batchNo; Rec."Batch No.")
                {
                    Caption = 'batchNo', Locked = true;
                    Editable = false;
                }
                field(lineCount; Rec."No. of Lines")
                {
                    Caption = 'lineCount', Locked = true;
                    Editable = false;
                }
                field(receivedAt; Rec."Received At")
                {
                    Caption = 'receivedAt', Locked = true;
                    Editable = false;
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        if Rec."Batch No." = '' then
            Error(PayloadRequiredErr);
        exit(true);
    end;

    var
        PayloadRequiredErr: Label 'The request must include "payload": the contribution batch JSON as a string.';
        PayloadText: Text;
}
