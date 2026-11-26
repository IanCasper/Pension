# Browser test script: Zamara Pension Contributions (Business Central)

You are testing a Business Central extension through the BC web client. It runs a pension scheme's monthly contribution cycle:

1. Master data.
2. File intake.
3. Background queue processing with retries.
4. Posting to a member ledger and the G/L.
5. Employer receipts.
6. Member statements.

Work through the sections in order, because later steps use data created by earlier ones.

## How to work

- **For each step:**
  1. Do the actions.
  2. Compare what you see with **Expected**.
  3. Record PASS, FAIL or BLOCKED in the results table at the end. Include the actual values and the exact text of any error or message.
- **Keep going after a failure.** Record it and move on, unless the step says **STOP**. If a later step depends on a failed one, mark that step BLOCKED.
- **Read messages before closing them.** Copy the full text of every BC message or error dialog into your notes first.
- **Confirmation dialogs:** answer **Yes** or **OK**, unless the step says otherwise.
- **File uploads:** you cannot use the operating system's file picker. When BC shows the upload dialog, **stop and ask me** to choose the file, and give me the full path from the step. Wait until I say "done".
- **Long operations:** *Process Queue Now* on about 2,000 lines can take a minute or more. Wait for the result message and do not click the action a second time.
- **Leave everything else alone:** do not change settings that a step does not mention, and do not delete records unless a step tells you to.
- **Amounts** are in the local currency and BC shows them as `27,000.00`. Values marked ★ assume the company had no pension data before step 1.2. If an ★ value differs but the logic holds, record the actual value and mark the step PASS with a note.

## Connection details

- **Base URL:** `http://localhost:8080/BC280T/`. If it doesn't load, ask me for the right URL.
- **Opening a page:** append `?page=<ID>`, for example `http://localhost:8080/BC280T/?page=50100`. If the wrong company opens, ask me for the company name and add `&company=<name>`.
- **Sign-in:** Windows authentication. If a login prompt appears, ask me.
- **If a URL fails,** use the search icon (Tell Me, Alt+Q) and type the page name.

| Page | ID | Page | ID |
|---|---|---|---|
| Pension Setup | 50100 | Contribution Queue | 50109 |
| Pension Schemes | 50101 | Member Ledger Entries | 50110 |
| Pension Employers | 50102 | Contribution Queue Monitor | 50112 |
| Pension Members | 50104 | Contribution Queue Run Log | 50113 |
| Contribution Batches | 50106 | Pension Receipts | 50115 |
| Posted Pension Receipts | 50118 | Customers (standard) | 22 |
| Job Queue Entries (standard) | 672 | AL Test Tool (standard) | 130451 |

## Before you start (I confirm these)

- The extension **Zamara Pension Contributions** is published.
- The company has no pension data yet.
- The allowed posting dates include 2026-09-01 to 2026-12-31. Check both General Ledger Setup and User Setup.

---

## 1. Setup and test data

**1.1 Pension Setup defaults.** Open Pension Setup (50100).
- **Expected:**
  - Remittance Due Day = 9
  - Queue Batch Size = 500
  - Max Retry Attempts = 3
- Record Late Penalty % as it is now (it may be 0).

**1.2 Generate test data.** On Pension Setup, choose **Generate Test Data**. The dialog *Generate Pension Test Data* opens. Fill it in and choose **OK**:

| Field | Value |
|---|---|
| Period (YYYY-MM) | `2026-09` |
| Received Date | `2026-10-05` |
| Bad Lines % | `3` |
| Employers | `50` |
| Members | `2000` |

- **Expected:** a summary message showing:
  - Employers: 50
  - Members: 2000
  - Batches created: 50, already received: 0
  - Queue lines: 2000
  - Deliberately bad lines: about 60, split roughly evenly between inactive member, wrong employer and over cap
- **Record the number of deliberately bad lines as `B`.** Later steps use it.
- If this step fails, **STOP** and report to me.

**1.3 Setup after generation.** Reopen Pension Setup.
- **Expected:**
  - Late Penalty % = 5
  - Default Bank Account No. = `PENBANK`
  - Member Nos., Employer Nos., Contribution Batch Nos. and Receipt Nos. are all filled in

**1.4 Scheme.** Open Pension Schemes (50101).
- **Expected:** a scheme `PENSCHEME` with:
  - Customer Posting Group `PENSION`
  - Contribution Receivable account `PEN1100`, not editable
  - Member Liability account `PEN2100`
  - Penalty Income account `PEN4100`
  - Employer Cap % = 10

**1.5 Employers.** Open Pension Employers (50102).
- **Expected:** 50 rows, `EMP0001` to `EMP0050`.
- Open `EMP0001`. **Expected:**
  - Scheme Code `PENSCHEME`
  - KRA PIN filled in (**record it**)
  - Employer Status Active
  - Active Members 40 ★
  - Customer Posting Group `PENSION`, not editable

**1.6 Employer is a standard customer.** Open Customers (22) and open customer `EMP0001`.
- **Expected:**
  - a **Pension** FastTab on the standard Customer Card
  - a **Pension** tab in the action bar, with Pension Employer Card, Pension Members, Contribution Batches and Pension Receipts
- From that tab, choose **Pension Employer Card**. **Expected:** the Pension Employer card for EMP0001 opens.
- Back on the Customer Card, choose **Pension Members**. **Expected:** the 40 members of EMP0001 ★.
- Open a customer that is not a pension employer, such as any customer without an EMP number. **Expected:** neither the Pension FastTab nor the Pension action tab is shown.

**1.7 Members.** Open Pension Members (50104).
- **Expected:** 2,000 rows ★. `MEM00001` has Employer No. `EMP0001`.
- **Record MEM00001's National ID No.** ★ It should be `30000001`.

---

## 2. Master data rules

**2.1 KRA PIN format.** Pension Employers → **New**. Enter Name `Browser Test Employer Ltd` and Scheme Code `PENSCHEME`, then KRA PIN `12345`.
- **Expected:** error "KRA PIN 12345 is not valid. The format is a letter, nine digits and a letter, for example A000000000Z."

**2.2 Duplicate KRA PIN.** On the same card, enter EMP0001's KRA PIN from step 1.5.
- **Expected:** error "KRA PIN … is already used by employer EMP0001."

**2.3 Valid KRA PIN and suspension.** Enter KRA PIN `P051234567X`. If BC says that PIN is already used, change the digits until one is accepted.
- **Expected:** the PIN is accepted, and Customer Posting Group shows `PENSION`.
- Set Employer Status to **Suspended**.
- **Record the new employer No.** ★ It should be `EMP0051`.

**2.4 E-mail format.** On the same card, enter E-Mail `not-an-email`.
- **Expected:** an error from standard BC about the email address.
- Clear the field, then close the card.

**2.5 Suspended employer cannot take members.** Pension Members → **New**. Enter First Name `Browser` and Last Name `Tester`, then Employer No. = the suspended employer from step 2.3.
- **Expected:** error "Employer … is suspended and cannot take new members or contributions."

**2.6 Required-field warning on close.** On the same member card, clear the Employer No. field and try to close the card.
- **Expected:** a confirmation that required fields are missing.
- Answer **No** to stay on the card.

**2.7 Scheme inherited from employer.** Set Employer No. to `EMP0001`.
- **Expected:** it is accepted, and Scheme Code becomes `PENSCHEME` and is not editable.

**2.8 Duplicate National ID.** Enter MEM00001's National ID No. from step 1.7.
- **Expected:** error "National ID No. … is already registered to member MEM00001."
- Change it to `99999901`. **Expected:** accepted.

**2.9 Age at joining.** Enter Date Joined `2026-11-01`, then Date of Birth `2010-01-01`.
- **Expected:** error "The member must be between 18 and 65 years old on the date joined…"
- Change Date of Birth to `1990-05-15`. **Expected:** accepted.

**2.10 Salary.** Enter Pensionable Salary `0`.
- **Expected:** error "Pensionable Salary must be greater than zero."
- Change it to `50000`. **Expected:** accepted.
- Close the card. **Record this member's No. as `T`.**

---

## 3. Intake

**3.1 Generated batches.** Open Contribution Batches (50106).
- **Expected:** 50 batches for Period 2026-09, with Source Generator.

**3.2 Import the sample JSON.** Choose **Import File**. When the upload dialog appears, ask me to choose:
`C:\Users\ikinyanjui\Documents\AL\Zamara\SampleFiles\EMP0001-202610-001.json`
- **Expected:** message "Batch … received with 3 lines. The lines are Pending and will be processed in the background."
- **Record the batch No. as `S`.**

**3.3 Batch header.** Open batch `S`.
- **Expected:**

| Field | Expected value |
|---|---|
| Message ID | EMP0001-202610-001 |
| Employer No. | EMP0001 |
| Period | 2026-10 |
| Received Date | 2026-11-12 |
| Due Date | 2026-11-09 |
| Control Total | 27,000.00 |
| No. of Lines | 3 |
| Pending Lines | 3 |
| Source | JSON File |
| Penalty Posted | No |

**3.4 Duplicate message ID.** Back on Contribution Batches, choose **Import File** again and ask me to choose the same file again.
- **Expected:** error "Message ID EMP0001-202610-001 has already been received as batch S. The same file cannot be loaded twice."
- No new batch appears.

**3.5 Control total mismatch.** Choose **Import File** and ask me to choose:
`C:\Users\ikinyanjui\Documents\AL\Zamara\SampleFiles\EMP0001-202610-003-bad-control-total.json`
- **Expected:** error "The batch is rejected: the line amounts add up to 27,000.00, but the control total is 26,000.00 (difference 1,000.00)."
- The number format may differ slightly. No new batch appears.

---

## 4. Processing run 1, posting and reconciliation

**4.1 Run the queue.** Pension Setup → **Process Queue Now**. Wait for the result.
- **Expected:** "2003 lines were processed." ★ That is the 2,000 generated lines plus the 3 sample lines.

**4.2 Failed lines.** Open Contribution Queue (50109) and filter Status = Failed.
- **Expected:**
  - The number of Failed lines equals `B`.
  - Each has Retry Count 1 and a Last Error.
- Use **Show Error** on two or three lines. **Expected:** errors of these kinds:
  - "Member … is Exited, not Active."
  - "Member … belongs to employer …, not to the batch employer …"
  - "Employer amount … exceeds the scheme cap of 10% …"

**4.3 Sample batch totals.** Open batch `S`.
- **Expected:**

| Field | Expected value |
|---|---|
| Status | Posted |
| Posted Lines | 3 |
| Failed Lines | 0 |
| Posted Amount | 27,000 |
| Member Ledger Amount | 27,000 |
| Invoiced Amount | 27,000 |
| Penalty Posted | Yes |
| Penalty Amount | 1,350 (5% of 27,000) |
| Outstanding (Employer) | 28,350 |

**4.4 Member ledger.** On batch `S`, choose **Member Ledger Entries**.
- **Expected:**
  - 6 entries: an Employee Contribution and an Employer Contribution for each of MEM00001, MEM00002 and MEM00003
  - Posting Date 2026-10-31 and Document No. = `S` on all six
  - Amounts total 27,000

**4.5 Employer invoices.** On batch `S`, choose **Employer Ledger Entries**. If the penalty is not listed there, use Pension Employers → EMP0001 → **Ledger Entries**.
- **Expected:** a contribution invoice:
  - Document No. `S`
  - Amount 27,000
  - Posting Date 2026-10-31
- **Expected:** a separate penalty invoice:
  - Document No. `S-P`
  - Amount 1,350
  - Posting Date 2026-11-12
  - Description mentions late remittance, EMP0001 and 2026-10

**4.6 G/L entries.** On batch `S`, choose **G/L Entries**.
- **Expected:**
  - a debit of 27,000 to `PEN1100` and a credit of 27,000 to `PEN2100`
  - **one** liability entry for the batch, not one per member

**4.7 Reconciliation.** On batch `S`, choose **Check Reconciliation**.
- **Expected:** message "Batch S reconciles." Member ledger, Employer invoice and G/L credit to Member Liability (PEN2100) all show 27,000.

**4.8 On-time batch, no penalty.** Open the 2026-09 batch for `EMP0001`.
- **Expected:**
  - Status Posted
  - Posted Lines 40 ★
  - Penalty Posted No: the due date is 2026-10-09 and it was received 2026-10-05
- **Check Reconciliation**. **Expected:** it reconciles.

**4.9 Batch with a bad line.** Open the 2026-09 batch for `EMP0002`.
- **Expected:**
  - Status **In Progress**: the failed line is retried automatically on the next run, so the batch is not finished yet
  - Failed Lines 1 ★
- **Check Reconciliation**. **Expected:** it still reconciles, because only posted lines are invoiced.

---

## 5. The same contribution is never posted twice

**5.1 Import the CSV.** Contribution Batches → **Import File**. Ask me to choose:
`C:\Users\ikinyanjui\Documents\AL\Zamara\SampleFiles\EMP0001-202610-002.csv`
- **Expected:** a batch with 3 lines and Source CSV File. **Record its No. as `C`.**
- It contains the same contributions as the JSON file under a different message ID.

**5.2 Run 2.** Pension Setup → **Process Queue Now**.
- **Expected:** "`B`+3 lines were processed." That is the retried failures plus the 3 CSV lines.

**5.3 CSV batch fails.** Open batch `C`.
- **Expected:**
  - Failed Lines 3
  - each line's error reads "A contribution for member MEM0000x and period 2026-10 has already been posted."
  - Invoiced Amount 0
  - Penalty Posted No

**5.4 No duplicate ledger entries.** Open Member Ledger Entries (50110) and filter Member No. = MEM00001.
- **Expected:** exactly 2 entries for 2026-10, plus 2 for 2026-09.

---

## 6. Retries, Dead Letter and Reprocess

**6.1 Run 3.** **Process Queue Now** once more. Then open Contribution Queue filtered to Failed.
- **Expected:**
  - the generator's bad lines now have Retry Count 3
  - the CSV lines have Retry Count 2

**6.2 Run 4.** **Process Queue Now**. Filter the queue to Dead Letter.
- **Expected:**
  - Dead Letter = `B` lines, all with Retry Count 4
  - the 3 CSV lines are still Failed, with Retry Count 3
- Open the 2026-09 batch for `EMP0002` again. **Expected:** Status **Completed with Errors**, because its only unposted line is now in Dead Letter and nothing is left to retry.

**6.3 Run 5.** **Process Queue Now**.
- **Expected:**
  - Dead Letter = `B` + 3
  - Failed = 0
  - Pending = 0

**6.4 Dead Letter is not retried automatically.** **Process Queue Now** again.
- **Expected:** "0 lines were processed."

**6.5 Fix the data, then Reprocess.**
1. In the queue, filtered to Dead Letter, find a line whose error is "Member … is Exited, not Active." Record its member No. `M` and its batch No.
2. Open member `M` and set Status to **Active**.
3. Back in the queue, select that line and choose **Reprocess**.
   - **Expected:** Status Pending, Retry Count 0, Last Error blank.
4. Choose **Process Queue Now**.
   - **Expected:** "1 lines were processed."
   - The line is Posted, and member `M` now has 2 member ledger entries for 2026-09.
5. Open that line's batch and choose **Check Reconciliation**.
   - **Expected:** it still reconciles.

**6.6 Reprocess without fixing.**
1. Select a Dead Letter line whose error is about the cap and choose **Reprocess**.
2. Choose **Process Queue Now**.
- **Expected:** the line goes back to Failed with Retry Count 1 and the same cap error.

---

## 7. Monitoring

**7.1 Queue Monitor.** Open the Contribution Queue Monitor (50112) and choose **Refresh**.
- **Expected:**
  - The status cues match the counts you saw in the Contribution Queue.
  - **Last Run** shows Started At, Duration (ms), Lines Processed, Lines per Second and Session ID.
  - **Most Common Errors** lists the error types from step 4.2.
  - **Outstanding Employer Receivable** is greater than 0.
- Click the Dead Letter cue. **Expected:** the queue opens filtered to Dead Letter.

**7.2 Run Log.** Choose **Run Log**.
- **Expected:**
  - one row per processing run, at least 8 rows by now
  - each row has a duration, a line count and posted, failed and dead letter counts

---

## 8. Receipting (the cash leg)

**8.1 New receipt.** Open Pension Receipts (50115) → **New**. Enter:
- Employer No. `EMP0001`
- Receipt Date `2026-11-23`
- Payment Reference `BROWSER-TEST-01`

**Expected:** Bank Account No. defaults to `PENBANK`.

**8.2 Suggest Lines.** Choose **Suggest Lines**.
- **Expected:** 2 allocation lines:
  - the 2026-09 batch for EMP0001, Outstanding 420,000 ★
  - batch `S`, Outstanding 28,350
- There is no line for batch `C`, because nothing was invoiced for it.

**8.3 Amount must match the lines.** Set the header Amount to `100000` and choose **Post**.
- **Expected:** error "The receipt amount 100,000.00 does not equal the total of the lines 448,350.00." ★

**8.4 Cannot over-allocate.** Change the line for batch `S` to `30000`, choose **Set Amount from Lines**, then **Post**.
- **Expected:** an error that the line allocates 30,000 to batch `S` but only 28,350 is outstanding. The error may appear as soon as you enter the amount.
- Change the line back to `28350`.

**8.5 Post a full receipt.** Choose **Set Amount from Lines**.
- **Expected:** Amount = Lines Total = 448,350 ★.
- Choose **Post** and confirm.
- **Expected:** the receipt leaves Pension Receipts and appears in Posted Pension Receipts (50118). **Record its No. as `R1`.**

**8.6 Bank and customer entries.** Open posted receipt `R1`.
- **Bank Entries**. **Expected:** one Bank Account Ledger Entry on `PENBANK` for 448,350.
- **Customer Entries**. **Expected:** a payment of −448,350 with Remaining Amount 0.

**8.7 Batch and employer closed.**
- Open batch `S`. **Expected:** Outstanding (Employer) = 0.
- Open Pension Employers → EMP0001 → **Ledger Entries**. **Expected:** the 2026-09 invoice, the `S` invoice and the `S-P` penalty all show Open = No.

**8.8 Partial receipt.**
1. Create a new receipt for `EMP0002` and choose **Suggest Lines**.
   - **Expected:** one line for the 2026-09 batch, Outstanding 408,000 ★. That is 420,000 less the over-cap line that never posted.
2. Change the line Amount to half the outstanding amount (204,000 ★).
3. Choose **Set Amount from Lines**, then **Post**.
- **Expected:**
  - The batch's Outstanding (Employer) equals the other half (204,000 ★).
  - EMP0002's invoice is still Open, with Remaining Amount 204,000 ★.

---

## 9. Member balance and statement

**9.1 Balance drill-down.** Open member `MEM00001`.
- **Expected:** Balance = 19,000 ★. That is 3,500 + 3,500 for 2026-09 and 6,000 + 6,000 for 2026-10.
- Click the Balance amount. **Expected:** Member Ledger Entries opens with the 4 entries.

**9.2 Statement for two months.** On the MEM00001 card, choose **Member Statement**. Set Start Date `2026-09-01` and End Date `2026-10-31`, then **Preview**.
- **Expected header:** member name, MEM00001, the National ID, employer EMP0001 and scheme PENSCHEME.
- **Expected rows:**

| Row | Employee | Employer | Running balance |
|---|---|---|---|
| Opening balance | | | 0 |
| 2026-09 | 3,500 | 3,500 | 7,000 |
| 2026-10 | 6,000 | 6,000 | 19,000 |

- **Expected footer:** employee total 9,500, employer total 9,500, closing balance 19,000 ★.

**9.3 Opening balance carried forward.** Run the statement again for `2026-10-01` to `2026-10-31`.
- **Expected:** opening 7,000, one row for 2026-10, closing 19,000 ★.

**9.4 No contributions in range.** Run it for `2026-11-01` to `2026-11-30`.
- **Expected:**
  - a single row reading "No contributions in this period"
  - opening = closing = 19,000 ★

**9.5 Member with no entries at all.** Run the statement for member `T` from step 2.10, for `2026-09-01` to `2026-10-31`.
- **Expected:**
  - a statement prints
  - "No contributions in this period"
  - opening = closing = 0

**9.6 Statements from the list.** In Pension Members, select MEM00001 and MEM00002 and choose **Member Statement** for 2026-09-01 to 2026-10-31.
- **Expected:** one statement per selected member.

---

## 10. Role center

**10.1** Open `http://localhost:8080/BC280T/?profile=PEN%20PENSION%20ADMINISTRATOR`. Do **not** change My Settings.
- **Expected:**
  - The *Pension Administrator* role center opens.
  - Cues show queue lines by status, open batches, late batches, outstanding employer receivable, unposted receipts and active members.
  - The parts *Recent Contribution Batches* and *Most Common Errors* are shown.
- Click the **Dead Letter** cue. **Expected:** the queue opens filtered to Dead Letter.

---

## 11. Background processing (Job Queue)

**11.1 Create new Pending work.** Pension Setup → **Generate Test Data**. Enter Period `2026-10` and Received Date `2026-11-05`, keep the other defaults, and choose **OK**.
- **Expected:** "already received: 1". EMP0001's 2026-10 message ID is the sample file's, so that batch is skipped.
- Record the number of queue lines created.

**11.2 One-off background run.** Choose **Process Queue in Background**.
- **Expected:** message "Processing has been scheduled in the background. Check the Queue Monitor for progress."
- Wait about 2 minutes. Open the Queue Monitor and choose **Refresh**.
- **Expected:**
  - Pending = 0
  - a new Run Log row with a different Session ID from your earlier runs
- If nothing has changed after 3 minutes, mark the step BLOCKED. The server's Job Queue (task scheduler) is probably not running.

**11.3 Recurring entry.** On Pension Setup, choose **Create Job Queue Entry**.
- **Expected:** message "A recurring Job Queue entry has been created. It processes the contribution queue every minute."
- Open Job Queue Entries (672). **Expected:** an entry "Process pension contribution queue" with Status Ready.
- Wait 2 minutes. **Expected:** new Run Log rows appear.
- **Cleanup:** select that Job Queue entry and choose **Set On Hold**.

---

## 12. Automated tests (only if I tell you the Test app is published)

These tests write their own data and change Pension Setup, so run them last.

1. Open AL Test Tool (130451).
2. Choose **Get Test Codeunits** → **Select Test Codeunits**, and pick codeunit **50140 PEN Contribution Tests**.
3. Choose **Run Tests**.

- **Expected:** all 12 tests show Success.
- For any failure, record the test name and the full error text.

---

## Not covered by this script

- **API intake** (`POST …/api/zamara/pensions/v1.0/companies({id})/contributionIntakes`). It needs a REST client.
- **Parallel processing at 20,000 lines.** It is a heavy performance run, done separately.

---

## Results

Fill this in as you go, then give me the completed table and a short summary of every FAIL and BLOCKED step.

Recorded values:

| Value | Where it comes from | Recorded value |
|---|---|---|
| `B` | Step 1.2 | |
| `S` | Step 3.2 | |
| `C` | Step 5.1 | |
| `T` | Step 2.10 | |
| `M` | Step 6.5 | |
| `R1` | Step 8.5 | |

| Step | Result (PASS/FAIL/BLOCKED) | Actual values / message text |
|---|---|---|
| 1.1 | | |
| 1.2 | | |
| 1.3 | | |
| 1.4 | | |
| 1.5 | | |
| 1.6 | | |
| 1.7 | | |
| 2.1 | | |
| 2.2 | | |
| 2.3 | | |
| 2.4 | | |
| 2.5 | | |
| 2.6 | | |
| 2.7 | | |
| 2.8 | | |
| 2.9 | | |
| 2.10 | | |
| 3.1 | | |
| 3.2 | | |
| 3.3 | | |
| 3.4 | | |
| 3.5 | | |
| 4.1 | | |
| 4.2 | | |
| 4.3 | | |
| 4.4 | | |
| 4.5 | | |
| 4.6 | | |
| 4.7 | | |
| 4.8 | | |
| 4.9 | | |
| 5.1 | | |
| 5.2 | | |
| 5.3 | | |
| 5.4 | | |
| 6.1 | | |
| 6.2 | | |
| 6.3 | | |
| 6.4 | | |
| 6.5 | | |
| 6.6 | | |
| 7.1 | | |
| 7.2 | | |
| 8.1 | | |
| 8.2 | | |
| 8.3 | | |
| 8.4 | | |
| 8.5 | | |
| 8.6 | | |
| 8.7 | | |
| 8.8 | | |
| 9.1 | | |
| 9.2 | | |
| 9.3 | | |
| 9.4 | | |
| 9.5 | | |
| 9.6 | | |
| 10.1 | | |
| 11.1 | | |
| 11.2 | | |
| 11.3 | | |
| 12 | | |
