-- ============================================================
-- EgoTrust — Two-Session Concurrency Exercise: SESSION B
-- MIT 8103 Advanced Database Systems — Portfolio 3
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- Run alongside SessionA.sql, following the step numbers.
-- Session B withdraws NGN 20,000 from account 0012345002.
-- ============================================================

-- ============ Scenario 1: lost update (no locking) ============

-- @step 2  B reads the SAME balance before A writes
\echo [B2] read balance
BEGIN;
SELECT balance AS bal FROM accounts WHERE account_number = '0012345002' \gset
\echo [B2] Session B read :bal

-- @step 4  B writes "what it read minus 20,000" and commits.
--          A's withdrawal is overwritten: the LOST UPDATE.
\echo [B4] write :bal - 20000 and commit
UPDATE accounts SET balance = :bal - 20000 WHERE account_number = '0012345002';
COMMIT;
\echo [B4] final balance (correct answer would be 1470000.00):
SELECT balance AS final_balance FROM accounts WHERE account_number = '0012345002';

-- ============ Scenario 2: the same, with SELECT ... FOR UPDATE ============

-- @step 7  B asks for the same row lock: this statement WAITS
--          until A commits in step 8, then returns A's new value
\echo [B7] read balance WITH row lock (waits for A)
BEGIN;
SELECT balance AS bal FROM accounts WHERE account_number = '0012345002' FOR UPDATE \gset
\echo [B7] Session B got the lock and read :bal

-- @step 9  B writes and commits: both withdrawals are kept
\echo [B9] write :bal - 20000 and commit
UPDATE accounts SET balance = :bal - 20000 WHERE account_number = '0012345002';
COMMIT;
\echo [B9] final balance (correct answer is 1470000.00):
SELECT balance AS final_balance FROM accounts WHERE account_number = '0012345002';

-- ============ Scenario 3: REPEATABLE READ snapshot ============

-- @step 11  B commits a change while A's snapshot is open
\echo [B11] credit 5000 and commit
UPDATE accounts SET balance = balance + 5000 WHERE account_number = '0012345002';

-- @step 13  B reverses its credit
\echo [B13] reverse the 5000 credit
UPDATE accounts SET balance = balance - 5000 WHERE account_number = '0012345002';

-- ============ Scenario 4: deadlock ============

-- @step 15  B locks account 0023456001 first
\echo [B15] lock account 0023456001
BEGIN;
UPDATE accounts SET balance = balance WHERE account_number = '0023456001';

-- @step 17  B now wants 0012345002, which A holds -> circular wait.
--           PostgreSQL detects the deadlock after ~1 s and aborts one session.
\echo [B17] request account 0012345002 (held by A)
UPDATE accounts SET balance = balance WHERE account_number = '0012345002';
COMMIT;
\echo [B17] Session B transaction finished
