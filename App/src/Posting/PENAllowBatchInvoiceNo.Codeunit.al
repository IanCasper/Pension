namespace Zamara.Pension;

using Microsoft.Finance.GeneralLedger.Journal;

/// <summary>
/// A batch can be invoiced more than once under the same Document No. (= Batch No.): once per processing
/// run that posts some of its lines, for example after a retry or when a batch spans two chunks.
/// Standard "Gen. Jnl.-Check Line" rejects a customer invoice whose number is already used, so
/// "PEN Contribution Post" binds this codeunit around the contribution invoice only, for that batch only.
/// </summary>
codeunit 50110 "PEN Allow Batch Invoice No."
{
    EventSubscriberInstance = Manual;
    Access = Internal;

    var
        AllowedBatchNo: Code[20];

    procedure SetBatchNo(BatchNo: Code[20])
    begin
        AllowedBatchNo := BatchNo;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Check Line", 'OnBeforeCheckSalesDocNoIsNotUsed', '', false, false)]
    local procedure SkipDocNoCheckForBatchInvoice(GenJournalLine: Record "Gen. Journal Line"; var IsHandled: Boolean)
    begin
        if AllowedBatchNo = '' then
            exit;
        if (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer) and
           (GenJournalLine."Document Type" = GenJournalLine."Document Type"::Invoice) and
           (GenJournalLine."Document No." = AllowedBatchNo)
        then
            IsHandled := true;
    end;
}
