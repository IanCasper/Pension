namespace Zamara.Pension.Test;

using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;
using Zamara.Pension;

/// <summary>
/// End-to-end tests for the contribution cycle. Each test builds its own scheme, employer,
/// members and batch through "PEN Test Library", then runs the real intake, processor and posting.
/// </summary>
codeunit 50140 "PEN Contribution Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Lib: Codeunit "PEN Test Library";

    // ---------- brief scenario 1 ----------

    [Test]
    procedure ValidLinePostsTwoMemberLedgerEntriesAndGLMatches()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        Batch: Record "PEN Contribution Batch";
        QueueLine: Record "PEN Contribution Queue";
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
        GLEntry: Record "G/L Entry";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        PensionMgt: Codeunit "PEN Pension Mgt";
        BatchNo: Code[20];
    begin
        // [GIVEN] An employer with one member and a batch with one valid line of 5,000 + 5,000, received on time
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 100000);
        Lib.AddLine(TempLine, Member."No.", 5000, 5000);
        BatchNo := Lib.ReceiveBatch(Employer."No.", Lib.UniqueMessageID(), Lib.OnTimeReceivedDate(), TempLine);

        // [WHEN] The queue is processed
        Lib.ProcessBatch(BatchNo);

        // [THEN] The line is Posted with two member ledger entries
        QueueLine.Get(BatchNo, 1);
        Lib.AreEqual(QueueLine.Status::Posted, QueueLine.Status, 'Queue line status');
        MemberLedgerEntry.SetRange("Batch No.", BatchNo);
        this.Lib.AreEqual(2, MemberLedgerEntry.Count(), 'Number of member ledger entries');
        MemberLedgerEntry.SetRange("Entry Type", MemberLedgerEntry."Entry Type"::"Employee Contribution");
        MemberLedgerEntry.CalcSums(Amount);
        Lib.AreEqual(5000, MemberLedgerEntry.Amount, 'Employee contribution');
        MemberLedgerEntry.SetRange("Entry Type", MemberLedgerEntry."Entry Type"::"Employer Contribution");
        MemberLedgerEntry.CalcSums(Amount);
        Lib.AreEqual(5000, MemberLedgerEntry.Amount, 'Employer contribution');

        // [THEN] The G/L credit to Member Liability equals the member ledger total, and so does the employer invoice
        GLEntry.SetRange("Document No.", BatchNo);
        GLEntry.SetRange("G/L Account No.", Scheme."Member Liability Acc.");
        GLEntry.CalcSums(Amount);
        Lib.AreEqual(-10000, GLEntry.Amount, 'G/L credit to Member Liability');
        GLEntry.SetRange("G/L Account No.", Scheme."Contribution Receivable Acc.");
        GLEntry.CalcSums(Amount);
        Lib.AreEqual(10000, GLEntry.Amount, 'G/L debit to Contribution Receivable');
        Batch.Get(BatchNo);
        Batch.CalcFields("Invoiced Amount");
        Lib.AreEqual(10000, Batch."Invoiced Amount", 'Employer invoice');
        Lib.IsTrue(PensionMgt.CheckReconciliation(Batch, false), 'Batch reconciles');
        Lib.AreEqual(Batch.Status::Posted, Batch.Status, 'Batch status');
    end;

    // ---------- brief scenario 2 ----------

    [Test]
    procedure ResubmittedBatchWithSameMessageIdIsRejected()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        QueueLine: Record "PEN Contribution Queue";
        MessageID: Text[100];
        BatchNo: Code[20];
    begin
        // [GIVEN] A batch that has been received
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 100000);
        Lib.AddLine(TempLine, Member."No.", 1000, 1000);
        MessageID := Lib.UniqueMessageID();
        BatchNo := Lib.ReceiveBatch(Employer."No.", MessageID, Lib.OnTimeReceivedDate(), TempLine);
        // asserterror rolls back everything since the last commit, so keep the first batch.
        Commit();

        // [WHEN] The same message ID is received again
        asserterror Lib.ReceiveBatch(Employer."No.", MessageID, Lib.OnTimeReceivedDate(), TempLine);

        // [THEN] It is rejected and nothing new is queued
        Lib.ExpectedErrorContains('has already been received');
        QueueLine.SetRange("Member No.", Member."No.");
        Lib.AreEqual(1, QueueLine.Count(), 'Only the first batch is queued');
    end;

    // ---------- brief scenario 3 ----------

    [Test]
    procedure OneInvalidLineFailsWhileTheOthersPost()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        OtherEmployer: Record Customer;
        Member1: Record "PEN Member";
        Member2: Record "PEN Member";
        OtherMember: Record "PEN Member";
        Batch: Record "PEN Contribution Batch";
        QueueLine: Record "PEN Contribution Queue";
        MemberLedgerEntry: Record "PEN Member Ledger Entry";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        PensionMgt: Codeunit "PEN Pension Mgt";
        BatchNo: Code[20];
    begin
        // [GIVEN] A batch of three lines where the second member belongs to another employer
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateEmployer(OtherEmployer, Scheme.Code);
        Lib.CreateMember(Member1, Employer."No.", 100000);
        Lib.CreateMember(OtherMember, OtherEmployer."No.", 100000);
        Lib.CreateMember(Member2, Employer."No.", 100000);
        Lib.AddLine(TempLine, Member1."No.", 3000, 3000);
        Lib.AddLine(TempLine, OtherMember."No.", 2000, 2000);
        Lib.AddLine(TempLine, Member2."No.", 1000, 1000);
        BatchNo := Lib.ReceiveBatch(Employer."No.", Lib.UniqueMessageID(), Lib.OnTimeReceivedDate(), TempLine);

        // [WHEN] The queue is processed
        Lib.ProcessBatch(BatchNo);

        // [THEN] Lines 1 and 3 are posted; line 2 failed with its reason stored on the line
        QueueLine.Get(BatchNo, 1);
        Lib.AreEqual(QueueLine.Status::Posted, QueueLine.Status, 'Line 1 status');
        QueueLine.Get(BatchNo, 3);
        Lib.AreEqual(QueueLine.Status::Posted, QueueLine.Status, 'Line 3 status');
        QueueLine.Get(BatchNo, 2);
        Lib.AreEqual(QueueLine.Status::Failed, QueueLine.Status, 'Line 2 status');
        Lib.AreEqual(1, QueueLine."Retry Count", 'Line 2 retry count');
        Lib.IsTrue(StrPos(QueueLine."Last Error", 'belongs to employer') > 0, 'Line 2 error text: ' + QueueLine."Last Error");

        // [THEN] Only the valid lines reached the ledgers, and the ledgers reconcile
        MemberLedgerEntry.SetRange("Batch No.", BatchNo);
        Lib.AreEqual(4, MemberLedgerEntry.Count(), 'Member ledger entries for two lines');
        MemberLedgerEntry.CalcSums(Amount);
        Lib.AreEqual(8000, MemberLedgerEntry.Amount, 'Member ledger total');
        Batch.Get(BatchNo);
        Lib.IsTrue(PensionMgt.CheckReconciliation(Batch, false), 'Batch reconciles');
    end;

    // ---------- brief scenario 4 ----------

    [Test]
    procedure LineThatKeepsFailingMovesToDeadLetterAndCanBeReprocessed()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        QueueLine: Record "PEN Contribution Queue";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        PensionMgt: Codeunit "PEN Pension Mgt";
        BatchNo: Code[20];
        MaxRetries: Integer;
        Attempt: Integer;
    begin
        // [GIVEN] A batch line for a member who has exited
        Lib.InitSetup();
        MaxRetries := Lib.GetMaxRetryAttempts();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 100000);
        Member.Status := Member.Status::Exited;
        Member.Modify(true);
        Lib.AddLine(TempLine, Member."No.", 1000, 1000);
        BatchNo := Lib.ReceiveBatch(Employer."No.", Lib.UniqueMessageID(), Lib.OnTimeReceivedDate(), TempLine);

        // [WHEN] It is processed once plus Max Retry Attempts times
        for Attempt := 1 to MaxRetries do begin
            Lib.ProcessBatch(BatchNo);
            QueueLine.Get(BatchNo, 1);
            Lib.AreEqual(QueueLine.Status::Failed, QueueLine.Status, StrSubstNo('Status after attempt %1', Attempt));
            Lib.AreEqual(Attempt, QueueLine."Retry Count", StrSubstNo('Retry count after attempt %1', Attempt));
        end;
        Lib.ProcessBatch(BatchNo);

        // [THEN] It is in Dead Letter, and further runs leave it there
        QueueLine.Get(BatchNo, 1);
        Lib.AreEqual(QueueLine.Status::"Dead Letter", QueueLine.Status, 'Status after the last retry');
        Lib.AreEqual(MaxRetries + 1, QueueLine."Retry Count", 'Retry count at Dead Letter');
        Lib.ProcessBatch(BatchNo);
        QueueLine.Get(BatchNo, 1);
        Lib.AreEqual(QueueLine.Status::"Dead Letter", QueueLine.Status, 'Dead Letter is not retried automatically');

        // [WHEN] The line is reprocessed manually
        QueueLine.SetRange("Batch No.", BatchNo);
        Lib.AreEqual(1, PensionMgt.ReprocessLines(QueueLine), 'Lines reset');

        // [THEN] It is Pending again with a fresh retry count
        QueueLine.Get(BatchNo, 1);
        Lib.AreEqual(QueueLine.Status::Pending, QueueLine.Status, 'Status after Reprocess');
        Lib.AreEqual(0, QueueLine."Retry Count", 'Retry count after Reprocess');
    end;

    // ---------- further acceptance criteria ----------

    [Test]
    procedure ControlTotalMismatchIsRejectedWithClearMessage()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        TempLine: Record "PEN Intake Line Buffer" temporary;
    begin
        // [GIVEN] Lines that add up to 2,000
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 100000);
        Lib.AddLine(TempLine, Member."No.", 1000, 1000);

        // [WHEN] The control total says 2,500
        asserterror Lib.ReceiveBatchWithControlTotal(Employer."No.", Lib.UniqueMessageID(), Lib.OnTimeReceivedDate(), 2500, TempLine);

        // [THEN] The batch is rejected and the message says why
        Lib.ExpectedErrorContains('control total');
    end;

    [Test]
    procedure LateBatchPostsExactlyOnePenalty()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member1: Record "PEN Member";
        Member2: Record "PEN Member";
        Batch: Record "PEN Contribution Batch";
        GLEntry: Record "G/L Entry";
        QueueLine: Record "PEN Contribution Queue";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        PensionMgt: Codeunit "PEN Pension Mgt";
        BatchNo: Code[20];
    begin
        // [GIVEN] A late batch where one line fails the first time (member exited)
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member1, Employer."No.", 100000);
        Lib.CreateMember(Member2, Employer."No.", 100000);
        Member2.Status := Member2.Status::Exited;
        Member2.Modify(true);
        Lib.AddLine(TempLine, Member1."No.", 5000, 5000);
        Lib.AddLine(TempLine, Member2."No.", 5000, 5000);
        BatchNo := Lib.ReceiveBatch(Employer."No.", Lib.UniqueMessageID(), Lib.LateReceivedDate(), TempLine);

        // [WHEN] It is processed, the failed line is fixed, and it is processed again
        Lib.ProcessBatch(BatchNo);
        Member2.Get(Member2."No.");
        Member2.Status := Member2.Status::Active;
        Member2.Modify(true);
        Lib.ProcessBatch(BatchNo);
        QueueLine.Get(BatchNo, 2);
        Lib.AreEqual(QueueLine.Status::Posted, QueueLine.Status, 'Second line posted on retry');

        // [THEN] Exactly one penalty was posted: 5% of the 20,000 control total, credited to Penalty Income
        Batch.Get(BatchNo);
        Lib.IsTrue(Batch."Penalty Posted", 'Penalty flag');
        Lib.AreEqual(1000, Batch."Penalty Amount", 'Penalty amount');
        GLEntry.SetRange("Document No.", Batch.GetPenaltyDocumentNo());
        GLEntry.SetRange("G/L Account No.", Scheme."Penalty Income Acc.");
        Lib.AreEqual(1, GLEntry.Count(), 'Penalty G/L entries');
        GLEntry.CalcSums(Amount);
        Lib.AreEqual(-1000, GLEntry.Amount, 'Penalty income credit');
        GLEntry.FindFirst();
        Lib.IsTrue(StrPos(GLEntry.Description, Employer."No.") > 0, 'Penalty description names the employer');

        // [THEN] Two processing runs posted two invoices, and the batch still reconciles
        Lib.IsTrue(PensionMgt.CheckReconciliation(Batch, false), 'Batch reconciles');
    end;

    [Test]
    procedure ReceiptPostsToBankAndClosesTheBatchInvoices()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        Batch: Record "PEN Contribution Batch";
        ReceiptHeader: Record "PEN Receipt Header";
        PostedReceiptHeader: Record "PEN Posted Receipt Header";
        BankAccountLedgerEntry: Record "Bank Account Ledger Entry";
        CustLedgerEntry: Record "Cust. Ledger Entry";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        ReceiptPost: Codeunit "PEN Receipt-Post";
        BatchNo: Code[20];
        Outstanding: Decimal;
    begin
        // [GIVEN] A late, processed batch: the employer owes contributions plus a penalty
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 100000);
        Lib.AddLine(TempLine, Member."No.", 4000, 4000);
        BatchNo := Lib.ReceiveBatch(Employer."No.", Lib.UniqueMessageID(), Lib.LateReceivedDate(), TempLine);
        Lib.ProcessBatch(BatchNo);
        Batch.Get(BatchNo);
        Outstanding := Batch.GetOutstandingAmount();
        Lib.AreEqual(8400, Outstanding, 'Outstanding = 8,000 contributions + 400 penalty');

        // [WHEN] A receipt for the full amount is entered with Suggest Lines and posted
        ReceiptHeader.Init();
        ReceiptHeader."Receipt Date" := Lib.LateReceivedDate();
        ReceiptHeader."Bank Account No." := Lib.CreateBankAccount();
        ReceiptHeader.Insert(true);
        ReceiptHeader.Validate("Employer No.", Employer."No.");
        ReceiptHeader.Validate(Amount, Outstanding);
        ReceiptHeader.Modify(true);
        ReceiptHeader.SuggestLines();
        ReceiptPost.Run(ReceiptHeader);

        // [THEN] The bank is debited, and the batch invoices are closed
        PostedReceiptHeader.Get(ReceiptPost.GetPostedReceiptNo());
        Lib.AreEqual(Outstanding, PostedReceiptHeader."Applied Amount", 'Applied amount');
        BankAccountLedgerEntry.SetRange("Document No.", PostedReceiptHeader."No.");
        BankAccountLedgerEntry.CalcSums(Amount);
        Lib.AreEqual(Outstanding, BankAccountLedgerEntry.Amount, 'Bank debit');
        Batch.FilterOpenInvoices(CustLedgerEntry);
        Lib.AreEqual(0, CustLedgerEntry.Count(), 'No open invoices left for the batch');
        Lib.AreEqual(0, Batch.GetOutstandingAmount(), 'Outstanding after receipt');
    end;

    [Test]
    procedure ReceiptWhoseAmountDiffersFromItsLinesIsRejected()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        ReceiptHeader: Record "PEN Receipt Header";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        BatchNo: Code[20];
    begin
        // [GIVEN] A processed batch and a receipt whose lines total less than its amount
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 100000);
        Lib.AddLine(TempLine, Member."No.", 1000, 1000);
        BatchNo := Lib.ReceiveBatch(Employer."No.", Lib.UniqueMessageID(), Lib.OnTimeReceivedDate(), TempLine);
        Lib.ProcessBatch(BatchNo);

        ReceiptHeader.Init();
        ReceiptHeader."Bank Account No." := Lib.CreateBankAccount();
        ReceiptHeader.Insert(true);
        ReceiptHeader.Validate("Employer No.", Employer."No.");
        ReceiptHeader.Validate(Amount, 5000);
        ReceiptHeader.Modify(true);
        ReceiptHeader.SuggestLines();

        // [WHEN] It is posted
        asserterror Codeunit.Run(Codeunit::"PEN Receipt-Post", ReceiptHeader);

        // [THEN] Posting is refused
        Lib.ExpectedErrorContains('does not equal the total of the lines');
    end;

    // asserterror rolls back everything since the last commit, including the records the test built,
    // so each case gets its own test that ends with its asserterror.

    [Test]
    procedure MemberCannotJoinSuspendedEmployer()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
    begin
        // [GIVEN] A suspended employer
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Employer."PEN Employer Status" := Employer."PEN Employer Status"::Suspended;
        Employer.Modify(true);

        // [WHEN/THEN] A member cannot be attached to it
        Member.Init();
        asserterror Member.Validate("Employer No.", Employer."No.");
        Lib.ExpectedErrorContains('suspended');
    end;

    [Test]
    procedure MemberCannotJoinBlockedScheme()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
    begin
        // [GIVEN] An active employer whose scheme is blocked
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Scheme.Get(Scheme.Code);
        Scheme.Blocked := true;
        Scheme.Modify(true);

        // [WHEN/THEN] A member cannot be attached to it
        Member.Init();
        asserterror Member.Validate("Employer No.", Employer."No.");
        Lib.ExpectedErrorContains('blocked');
    end;

    [Test]
    procedure DuplicateNationalIDIsRejected()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        SecondMember: Record "PEN Member";
    begin
        // [GIVEN] An existing member
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 100000);

        // [WHEN/THEN] Another member cannot use the same National ID
        SecondMember.Init();
        asserterror SecondMember.Validate("National ID No.", Member."National ID No.");
        Lib.ExpectedErrorContains('already registered');
    end;

    [Test]
    procedure OverCapEmployerAmountFails()
    var
        Scheme: Record "PEN Scheme";
        Employer: Record Customer;
        Member: Record "PEN Member";
        QueueLine: Record "PEN Contribution Queue";
        TempLine: Record "PEN Intake Line Buffer" temporary;
        BatchNo: Code[20];
    begin
        // [GIVEN] A 10% cap and a salary of 50,000, so the employer may pay at most 5,000
        Lib.InitSetup();
        Lib.CreateScheme(Scheme, 10);
        Lib.CreateEmployer(Employer, Scheme.Code);
        Lib.CreateMember(Member, Employer."No.", 50000);
        Lib.AddLine(TempLine, Member."No.", 1000, 5001);
        BatchNo := Lib.ReceiveBatch(Employer."No.", Lib.UniqueMessageID(), Lib.OnTimeReceivedDate(), TempLine);

        // [WHEN] The queue is processed
        Lib.ProcessBatch(BatchNo);

        // [THEN] The line fails on the cap rule
        QueueLine.Get(BatchNo, 1);
        Lib.AreEqual(QueueLine.Status::Failed, QueueLine.Status, 'Status');
        Lib.IsTrue(StrPos(QueueLine."Last Error", 'exceeds the scheme cap') > 0, 'Error text: ' + QueueLine."Last Error");
    end;
}
