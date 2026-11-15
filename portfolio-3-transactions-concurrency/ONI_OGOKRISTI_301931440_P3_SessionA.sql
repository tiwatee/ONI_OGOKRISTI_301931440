-- ============================================================
-- EgoTrust — Two-Session Concurrency Exercise: SESSION A
-- MIT 8103 Advanced Database Systems — Portfolio 3
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- Open two psql windows on the same egotrust database (after the
-- Portfolio 1 schema and sample data). Run the numbered steps in
-- order, alternating between this file and SessionB.sql:
--   step 1 here, step 2 in B, step 3 here, ...
-- Copy each step's statements into this window and press Enter.
--
-- Account used: 0012345002 (Tunde Adeyemi, current, NGN 1,500,000).
-- Session A withdraws NGN 10,000; Session B withdraws NGN 20,000.
-- Correct final balance after both: NGN 1,470,000.
-- The last step resets the balance so the ledger stays consistent.
-- ============================================================

-- ============ Scenario 1: lost update (no locking) ============

-- @step 1  A reads the balance into a psql variable
\echo [A1] read balance
BEGIN;
SELECT balance AS bal FROM accounts WHERE account_number = '0012345002' \gset
\echo [A1] Session A read :bal

-- @step 3  A writes "what it read minus 10,000" and commits
\echo [A3] write :bal - 10000 and commit
UPDATE accounts SET balance = :bal - 10000 WHERE account_number = '0012345002';
COMMIT;

-- ============ Scenario 2: the same, with SELECT ... FOR UPDATE ============

-- @step 5  Reset to the starting balance (outside any transaction)
\echo [A5] reset balance to 1500000
UPDATE accounts SET balance = 1500000.00 WHERE account_number = '0012345002';

-- @step 6  A locks the row while reading it
\echo [A6] read balance WITH row lock
BEGIN;
SELECT balance AS bal FROM accounts WHERE account_number = '0012345002' FOR UPDATE \gset
\echo [A6] Session A read :bal (row now locked)

-- @step 8  A writes and commits, releasing the lock
\echo [A8] write :bal - 10000 and commit (releases lock)
UPDATE accounts SET balance = :bal - 10000 WHERE account_number = '0012345002';
COMMIT;

-- ============ Scenario 3: REPEATABLE READ snapshot ============

-- @step 10  A starts a REPEATABLE READ transaction and reads
\echo [A10] REPEATABLE READ: first read
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance AS first_read FROM accounts WHERE account_number = '0012345002';

-- @step 12  A reads again (same value: B's committed change is invisible),
--           then tries to update the row B changed: serialization failure
\echo [A12] REPEATABLE READ: second read (B has committed a change meanwhile)
SELECT balance AS second_read FROM accounts WHERE account_number = '0012345002';
\echo [A12] try to update the row B changed
UPDATE accounts SET balance = balance - 1000 WHERE account_number = '0012345002';
ROLLBACK;

-- ============ Scenario 4: deadlock ============

-- @step 14  A locks account 0012345002 first
\echo [A14] lock account 0012345002
BEGIN;
UPDATE accounts SET balance = balance WHERE account_number = '0012345002';

-- @step 16  A now wants 0023456001, which B holds -> waits
\echo [A16] request account 0023456001 (held by B)
UPDATE accounts SET balance = balance WHERE account_number = '0023456001';
COMMIT;
\echo [A16] Session A transaction finished

-- @step 18  Restore the starting balance so the ledger reconciles
\echo [A18] restore balance to 1500000
UPDATE accounts SET balance = 1500000.00 WHERE account_number = '0012345002';
SELECT account_number, balance FROM accounts WHERE account_number = '0012345002';
