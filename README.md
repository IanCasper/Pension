# Zamara Pension Contributions (Business Central extension)

This extension runs the monthly contribution cycle of an occupational pension scheme:

1. Onboard schemes, employers and members.
2. Receive employer contribution schedules (JSON, CSV or API).
3. Process them in the background through the Job Queue, with retries and a dead letter status.
4. Post a member sub-ledger, invoice employers and charge late penalties, all through standard posting.
5. Receipt employer cash to the bank.
6. Print member statements.

- **Target:** Business Central 28 on-prem (runtime 17.0).
- **Object IDs:** 50100–50149, prefix `PEN`, namespace `Zamara.Pension`.

| Folder | Contents |
|---|---|
| `App/` | The extension: `Zamara Pension Contributions`. Object IDs 50100–50139. |
| `Test/` | Test app: `Zamara Pension Contributions Tests`. Object IDs 50140–50149. |
| `SampleFiles/` | The brief's sample batch as JSON and CSV, plus a file with a wrong control total. |
| `Zamara.code-workspace` | Opens both projects together. Open this file, not the root folder. |

---

## 1. How to run it

1. Open `Zamara.code-workspace`. Download symbols for `App`, then publish it (F5) to `http://bcserver/BC`.
2. Optional: in **My Settings**, switch the role to **Pension Administrator**. Its role center (page 50122) has:
   - **Cues:** queue lines by status, open batches, batches with errors, late batches, outstanding employer receivable, unposted receipts, active members, employers and schemes.
   - **Parts:** the last processor run, recent batches and the most common errors.
   - **Navigation:** every pension page, grouped as Contributions, Employer Receivables, Membership and Setup.
   - **Actions:** Import Contribution File, Process Queue in Background, Generate Test Data, and New Member / Employer / Receipt.
3. Search for **Pension Setup**. Choose **Generate Test Data**, set the period to `2026-09`, and keep the defaults: 50 employers, 2,000 members, 3% bad lines. This creates:
   - G/L accounts `PEN1000`–`PEN4100`
   - customer posting group `PENSION`
   - bank account `PENBANK`
   - number series starting at `EMP0001` and `MEM00001`
   - scheme `PENSCHEME`
   - 50 employers, 2,000 members, and one batch per employer
4. Open **Contribution Batches**, choose **Import File**, and pick `SampleFiles/EMP0001-202610-001.json`.
   - The batch lands with 3 Pending lines.
   - Import the same file again: it is rejected because the message ID was already received.
   - Import `EMP0001-202610-003-bad-control-total.json`: it is rejected, and the message shows both totals.
5. Process the queue. Use either **Pension Setup → Process Queue Now**, **Process Queue in Background**, or **Create Job Queue Entry** (recurring, every minute).
6. Open a batch and use **Check Reconciliation**, **Member Ledger Entries**, **Employer Ledger Entries** and **G/L Entries**.
7. Choose **Generate Receipts**, or create a receipt by hand: **Pension Receipts → New → Suggest Lines → Post**.
8. Open a member and choose **Member Statement**.

Notes on the samples:

- **Why period `2026-09`:** the generator gives each batch the message ID `<Employer>-<YYYYMM>-001`. That is the same ID as the brief's sample for 2026-10. Generating 2026-09 leaves 2026-10 free for the sample file. Generate 2026-10 instead to see the duplicate rejection at once.
- **JSON and CSV together:** the CSV sample (`…-002.csv`) holds the same contributions under a different message ID. Whichever of the two is processed second fails every line with "already been posted". That shows the rule that the same contribution is never posted twice.

**Tests:** build `App` and copy the `.app` into `Test/.alpackages` (or rely on the workspace project reference). Publish `Test`, then run codeunit **50140 PEN Contribution Tests** from the AL Test Tool. The test app has no dependency on the Microsoft test libraries; its assertions live in codeunit 50141. The only toolkit requirement is the Test Runner that hosts the AL Test Tool page.

---

## 2. Design decisions

### Employers are standard customers

The brief describes a `PEN Employer` table. I implemented employers as **Customers** with a table extension instead (`PEN Pension Employer`, `PEN Scheme Code`, `PEN KRA PIN`, `PEN Employer Status`, `PEN Member Count`). The **PEN Employer List / Card** pages are built on the Customer table with a filter on that flag.

Reasons:

- The employer owes money: contributions and penalties. Keeping that debt in the standard customer ledger gives due dates, ageing, statements, application of payments and the receivables control account for free, all through standard posting.
- A separate employer table plus a customer would need two-way synchronisation for no benefit.

Every rule from the brief still applies:

- Name, scheme and KRA PIN are required.
- The KRA PIN must match the format `A000000000Z` and be unique.
- The email format is validated by the standard Customer field.
- Status is Active or Suspended.
- `Member Count` is a FlowField counting active members.

`PEN Employer Status` is deliberately separate from `Customer.Blocked`. A suspended employer must still be able to pay what it owes, so receipts must still post.

### Money flow

```
Schedule processed : Dr Employer (customer)  -> Contribution Receivable (customer posting group)
                     Cr Member Liability                          + 2 member ledger entries per line
Late penalty       : Dr Employer (customer)   Cr Penalty Income   (once per batch)
Receipt posted     : Dr Bank account          Cr Employer         (applied to the batch's invoices)
```

- All G/L postings go through `Gen. Journal Line` and `Gen. Jnl.-Post Line.RunWithCheck`. Nothing is inserted into `G/L Entry` directly.
- **Contribution Receivable Acc.** on the scheme comes from the scheme's **Customer Posting Group** and is read-only. That keeps the brief's field and the account the customer posting actually hits identical. Setting a scheme on an employer sets the employer's customer posting group.
- **The member ledger is for members only.** The employer side lives in the customer ledger and the G/L.

### Master data rules

| Rule | Where it is enforced |
|---|---|
| A member cannot join a suspended employer or a blocked scheme (criterion 1) | `Member."Employer No."` OnValidate and `Member.OnInsert`, via `Customer.PENCheckCanAcceptMembers()`. The line validation checks it again at processing time. |
| Duplicate National ID is rejected (criterion 2) | OnValidate and OnInsert, through a key on National ID. |
| Balance drills down to the ledger entries (criterion 3) | `Balance` is a FlowField on `PEN Member Ledger Entry`. That table's `DrillDownPageId` opens the entries. |
| Age must be 18 to 65 at joining | Checked whenever Date of Birth or Date Joined changes and both are filled. 65 is allowed until the day before the 66th birthday. |
| Required fields | Shown as mandatory on the cards. Closing an incomplete card asks for confirmation. `CheckMandatoryFields()` runs where the record is used: an incomplete employer cannot take members, and an incomplete member's lines fail validation. I did not block saving, because cards insert the record before the user has filled every field. |
| Employer KRA PIN uniqueness | Checked in OnValidate. It is not a unique database key, because a new customer starts with a blank PIN. |

### Intake (Part 2)

- **One codeunit for every route.** The JSON upload, CSV upload, API page and data generator all fill the same buffers and call `PEN Contribution Intake.ReceiveBatch`.
- **Structural checks only:**
  - required fields are present
  - Period matches `YYYY-MM`
  - dates and numbers parse in invariant (XML) format, so `6000.00` reads the same in every client language
  - amounts are ≥ 0 and a line is not zero
  - there is at least one line
  - **the sum of the lines equals the control total**, otherwise the error states both figures
- **Duplicate message IDs** are caught twice. A lookup gives the clear message. A **`Unique = true` key on Message ID** protects against two uploads racing.
- Intake is all or nothing. It creates the header and one `Pending` queue line per member line.
- Queue lines are keyed `(Batch No., Line No.)` with no AutoIncrement, so the inserts are buffered.
- **CSV:**
  - Columns are found by header name, so their order does not matter.
  - Batch-level columns must be the same on every row.
  - A UTF-8 byte order mark is stripped.
  - **Limitation:** quoted cells that contain commas are not supported. The format in the brief never needs them.
- **API:** `POST /api/zamara/pensions/v1.0/companies({id})/contributionIntakes` with body `{"payload": "<batch JSON as a string>"}`. A rejected batch returns HTTP 400 with the reason. The raw payload is kept on `PEN API Intake Request` for audit.

### Background processing (Part 3)

`PEN Queue Processor` (codeunit 50101) runs from the Job Queue. Every step is a short transaction:

| Step | What happens | Transaction |
|---|---|---|
| Prepare (once per run) | Lines left in `Processing` by a session that no longer exists go back to `Pending`. `Failed` lines go back to `Pending` for their retry. | Commit |
| Claim | Up to *Queue Batch Size* `Pending` lines become `Processing`, stamped with session ID, server instance and time. | Commit |
| Validate | Read-only rules. A failing line gets its error text stored, its retry count raised, and moves to `Failed`, or to `Dead Letter` once the retry count exceeds *Max Retry Attempts*. | Commit |
| Post | `Codeunit.Run("PEN Contribution Post")` on the valid lines. If posting raises an error, the whole chunk rolls back and each of its lines is marked `Failed` with that error. | Commit |

- **One bad line never stops the others.** Validation returns error text instead of raising an error, so no `TryFunction` is involved and no database write ever happens inside one. A posting-level error, such as a missing G/L account, fails only that chunk, and those lines are retried later.
- **Retries:** a line gets 1 attempt plus *Max Retry Attempts* retries. With the default of 3, the 4th failure moves it to Dead Letter. Retries happen on the next run, never within the same run, so a broken line cannot loop.
- **Batch status** follows its lines:
  - **Received:** no line has been processed yet.
  - **In Progress:** some lines are Pending, Processing or Failed. Failed lines are retried automatically, so the batch is not finished.
  - **Posted:** every line is posted.
  - **Completed with Errors:** nothing is left to retry, and at least one line is in Dead Letter. These batches feed the *Batches with Errors* cue.
- **Reprocess** is available on the queue list and the batch subform. It resets the selected Failed or Dead Letter lines to `Pending` with a retry count of 0.
- **Validation rules:**
  - the member exists, is Active and belongs to the batch's employer
  - the employer is an active pension employer with an unblocked scheme
  - no Posted line exists for the same member and period, checked both in the database and within the current run
  - the employer amount is no more than *Employer Cap %* of pensionable salary
- **A cap of 0 means the scheme has no cap.**
- **Integration events:**
  - `OnBeforeValidateQueueLine` / `OnAfterValidateQueueLine` (subscribers report a failure by setting `ErrorText`)
  - `OnAfterPostQueueLine`
  - `OnBeforePostContributionInvoice`, `OnBeforePostPenaltyInvoice`
  - `OnBeforeReceiveBatch` / `OnAfterReceiveBatch`
  - `OnBeforePostReceiptPayment` / `OnAfterPostReceipt`

### How two Job Queue entries are prevented from processing the same line

1. **Claiming is serialised.** Each claim locks the single `PEN Pension Setup` row (`LockTable` + `Get`), which works as a mutex. While the lock is held, the session picks Pending lines, sets them to `Processing` with its session ID, and commits. A second session waits on the lock for a few milliseconds. When it gets the lock, those lines are no longer `Pending`. Validation and posting happen after the commit, so they run in parallel.
2. **Ownership is checked before posting.** The posting codeunit re-reads each line with `UpdLock` and posts it only if it is still `Processing` and stamped with *this* session. A line taken over by another session is skipped.
3. **The member ledger itself is checked.** Under that lock, posting checks that no member ledger entry exists for the member and period. If one does, the line fails instead of posting twice.
4. **Crashed runs are recovered.** At the start of each run, `Processing` lines whose session is no longer in `Active Session` go back to `Pending`. A run that died mid-chunk therefore never strands lines.
5. **Entry numbers never collide.** `PEN Member Ledger Entry."Entry No."` is `AutoIncrement` (a SQL identity), so two posting sessions never compete for the same number and never need `FindLast + 1` under a table lock.
6. **The penalty is posted exactly once.** `Penalty Posted` is set in the same transaction as the penalty posting.
7. **No Job Queue category is set** on the entries. A category would make the Job Queue run them one at a time, which would defeat the parallel demo.

### Posting (Part 4)

- **Member ledger:** each posted line creates 2 entries, `Employee Contribution` and `Employer Contribution`. Positive amounts increase the member's balance.
  - Posting Date is the last day of the period.
  - `Document No.` = `Batch No.`, which is also the document number of the employer invoice and its G/L entries (criterion 2).
  - Posted By and Posted At are stored.
- **One summarised invoice per batch per processing run**, for the total of the lines posted in that run. There is no G/L entry per member.
  - A batch processed in one go gets exactly one invoice: Dr Contribution Receivable, Cr Member Liability.
  - When lines are retried later, or a batch is larger than the chunk size, a further invoice with the same Document No. covers those lines.
  - Every reconciliation filters by Document No., so the totals still match.
  - Standard posting rejects a second customer invoice with a number that is already used ("Sales Invoice … already exists"). `PEN Contribution Post` therefore binds codeunit `PEN Allow Batch Invoice No.` around the contribution invoice only. It skips that check through `OnBeforeCheckSalesDocNoIsNotUsed`, and only for the batch being invoiced.
- **Late penalty:**
  - **When a batch is late:** its received date is after the *Remittance Due Day* of the month following the period. The due day is clamped to the end of that month. The due date is calculated at intake and stored on the batch, so a later change to the setup does not change history.
  - **Amount:** *Late Penalty %* × **control total** (the amount the employer was due to remit).
  - **Posting:** a separate customer invoice, Dr Employer, Cr Penalty Income. Its Document No. is `<Batch No.>-P` and its posting date is the received date. The description names the employer and the period.
  - **When it is posted:** in the first processing run that posts lines for the batch. The `Penalty Posted` flag makes it once per batch (criterion 3).
  - **The brief's sample:** period 2026-10 is due on 2026-11-09 and was received on 2026-11-12, so it is late.

### Receipting (the cash leg)

- **Documents:** `PEN Receipt Header` / `Line` → **Post** → `PEN Posted Receipt Header` / `Line`.
- **Lines:** each line allocates part of the receipt to one batch. A line with no batch is a payment on account. **Suggest Lines** proposes every batch of the employer that still has an outstanding amount.
- **Posting:**
  1. For each batch line, the batch's open invoices get `Applies-to ID` and `Amount to Apply`, oldest first: the contribution invoice, then the penalty. The standard `Cust. Entry-Edit` codeunit writes these.
  2. One payment is posted through `Gen. Jnl.-Post Line`: Dr Bank, Cr Employer, `Applies-to ID` = receipt no. Whatever is not allocated stays open on account.
  3. The receipt moves to the posted tables.
  4. Everything happens in one transaction.
- **Checks:**
  - the receipt amount equals the lines total
  - every line amount is greater than zero
  - no line is more than the batch's outstanding amount
  - the bank account is not blocked
  - the employer is a pension employer

### Member statement (Part 5)

Report **50100 PEN Member Statement** has an RDLC layout and runs from the Member card (current member) and the Member list (selected members). For each member it shows:

- **Header:** name, number, National ID, employer, scheme and the date range.
- **Opening balance:** all member ledger entries before the start date.
- **One row per period:** employee share, employer share, period total and running balance.
- **Footer:** employee and employer totals, then the closing balance.

Closing = opening + contributions in the range, by construction (criterion 1). A member with no entries in the range gets a statement whose single row reads "No contributions in this period", with closing = opening (criterion 2).

### Test data (Part 6)

The generator can run more than once. Existing employers and members are reused, and batches already received for the period are skipped.

- **Members:** created in blocks per employer, so `MEM00001`–`MEM00040` belong to `EMP0001`, matching the sample files. Salaries are 60,000–150,000 and the cap is 10%. Contributions are 5% + 5%.
- **Bad lines:** at the default 3%, about every 100th line is made to fail, in turn as:
  - an exited member
  - a member of another employer
  - an employer amount over the cap
- **Receipts:** **Generate Receipts** posts receipts for about 70% of the outstanding batches in full and 20% in half, and leaves 10% unpaid.

---

## 3. How the member ledger and G/L were verified to reconcile

- **Per batch:** the batch action **Check Reconciliation** (`PEN Pension Mgt.CheckReconciliation`) compares three numbers:
  1. Σ member ledger entries where `Batch No.` = batch
  2. Σ employer invoices (`Detailed Cust. Ledg. Entry`, Initial Entry, Invoice) where `Document No.` = batch
  3. −Σ G/L entries on the scheme's Member Liability account where `Document No.` = batch

  All three must be equal (criterion 1).
- **In automated tests:**
  - `ValidLinePostsTwoMemberLedgerEntriesAndGLMatches` asserts the liability credit, the receivable debit, the invoice and the member ledger total.
  - `OneInvalidLineFailsWhileTheOthersPost` and `LateBatchPostsExactlyOnePenalty` assert that reconciliation still holds with failures and retries.
- **For the cash leg:** `ReceiptPostsToBankAndClosesTheBatchInvoices` asserts that the bank ledger debit equals the amount applied, and that no invoice for the batch is left open.

## 4. Tests

Codeunit 50140 `PEN Contribution Tests`. Every test builds its own scheme, G/L accounts, employer, members and batch.

| Test | Covers |
|---|---|
| `ValidLinePostsTwoMemberLedgerEntriesAndGLMatches` | Brief scenario 1 |
| `ResubmittedBatchWithSameMessageIdIsRejected` | Brief scenario 2 |
| `OneInvalidLineFailsWhileTheOthersPost` | Brief scenario 3 |
| `LineThatKeepsFailingMovesToDeadLetterAndCanBeReprocessed` | Brief scenario 4, plus Reprocess |
| `ControlTotalMismatchIsRejectedWithClearMessage` | Part 2, criterion 2 |
| `LateBatchPostsExactlyOnePenalty` | Part 4, criterion 3, across two processing runs |
| `ReceiptPostsToBankAndClosesTheBatchInvoices` | Cash leg |
| `ReceiptWhoseAmountDiffersFromItsLinesIsRejected` | Cash leg validation |
| `MemberCannotJoinSuspendedEmployer`, `MemberCannotJoinBlockedScheme` | Part 1, criterion 1 |
| `DuplicateNationalIDIsRejected` | Part 1, criterion 2 |
| `OverCapEmployerAmountFails` | Cap rule |

`InitSetup` in the test library sets Max Retry Attempts to 3 and Late Penalty % to 5 on the shared setup record. The tests use the processor's batch filter (`SetBatchFilter`), so they only touch their own lines. Run them in a test company, or with the standard isolation runner.

## 5. Performance (stretch goal)

What is in place:

- **Lookups:** member, employer and scheme are cached per run in temporary records and dictionaries, loaded with `SetLoadFields` and `ReadCommitted`. Missing records are cached too.
- **Claiming:** uses the `(Status, Batch No., Line No.)` key, which matches the filter and the sort.
- **Duplicate check:** uses the `(Member No., Period, Status)` key.
- **G/L posting:** one journal line per batch per chunk, not per member.
- **Intake:** inserts are buffered (no AutoIncrement on the queue).
- **Generator:** uses `No. Series - Batch`, so numbering does not lock per member.
- **Run log:** every run writes `PEN Queue Run Log` (duration, lines per second, chunk count, posted, failed and dead letter counts) and calls `Session.LogMessage` (`PEN0001` per run, `PEN0002` per chunk).

| Scenario (20,000 lines) | Chunk size | Duration | Lines/s |
|---|---|---|---|
| Before optimisation | 500 | _to measure_ | _to measure_ |
| After optimisation | 500 | _to measure_ | _to measure_ |
| After, chunk size 1,000 | 1000 | _to measure_ | _to measure_ |

**To measure:** generate with 20,000 members, choose **Process Queue Now**, and read the **Queue Run Log**.

## 6. Monitoring (stretch goal)

**Contribution Queue Monitor** shows:

- line counts by status, as cues that drill down
- open batches and unposted receipts
- the last run's start time, duration, line count, throughput and session
- the total outstanding employer receivable
- the five most common errors (numbers masked, so similar errors group together)

## 7. Parallel processing (stretch goal)

1. Choose **Create Job Queue Entry** twice on Pension Setup.
2. Generate 20,000 lines.
3. Watch **Queue Run Log**: two session IDs overlap in time.

Afterwards, every line is in exactly one final status, and the count of member ledger entries equals 2 × the posted lines (no duplicates for any member and period).

## 8. Not finished / known limitations

- The test app and the performance table above have not been run yet. The code was written and checked against the BC 28.5 symbols in VS Code, but it has not been published to a server.
- CSV cells that are quoted and contain commas are not supported.
- If master data changes during a single processor run, that run still uses the cached values. Each run starts with fresh caches.
- Penalties use the control total. If the business wants the penalty on the posted total instead, `PEN Pension Mgt.CalcPenaltyAmount` is the single place to change.
- A reversal or correction flow for a posted contribution (credit memo and reversing member ledger entries) is not included.
