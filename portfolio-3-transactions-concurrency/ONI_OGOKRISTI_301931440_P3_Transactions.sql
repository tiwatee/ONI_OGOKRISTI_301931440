-- ============================================================
-- EgoTrust — Transactions and Concurrency Control
-- MIT 8103 Advanced Database Systems — Portfolio 3
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- Run on a freshly seeded database (ONI_OGOKRISTI_301931440_P1_Schema.sql + ONI_OGOKRISTI_301931440_P1_SampleData.sql), in psql:
--   psql -U postgres -d egotrust -f ONI_OGOKRISTI_301931440_P3_Transactions.sql
-- Two statements in this script are EXPECTED to fail (A2 and A3);
-- those errors are the point of the demonstration. Do not run with
-- ON_ERROR_STOP=1.
--
-- Accounts used (from the seed data):
--   ...0001  0012345001  Tunde Adeyemi   savings  NGN 249,950.00
--   ...0002  0012345002  Tunde Adeyemi   current  NGN 1,500,000.00
--   ...0003  0023456001  Ngozi Eze       savings  NGN 850,000.00
-- ============================================================


-- ============================================================
-- PART A: Basic Transaction Operations
-- ============================================================

-- ------------------------------------------------------------
-- A1: Successful Intrabank Transfer (COMMIT)
-- Atomicity: the debit, the credit, both ledger entries and the
-- transfer record all succeed together, or none of them happen.
-- Tunde Adeyemi (0012345001) sends NGN 25,000 to Ngozi Eze (0023456001).
-- ------------------------------------------------------------
BEGIN;

    -- Lock both accounts in a fixed order (ascending account_id).
    -- Every transfer locks in the same order, which prevents deadlocks (see C4).
    SELECT account_id, account_number, balance
    FROM accounts
    WHERE account_id IN ('d4e5f6a7-0001-4000-8000-000000000001',
                         'd4e5f6a7-0001-4000-8000-000000000003')
    ORDER BY account_id
    FOR UPDATE;

    -- Debit the source. If the balance is too low, CHECK (balance >= 0)
    -- raises an error, the transaction is aborted and nothing below takes effect.
    UPDATE accounts
    SET balance = balance - 25000.00, updated_at = NOW()
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';

    -- Credit the destination
    UPDATE accounts
    SET balance = balance + 25000.00, updated_at = NOW()
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000003';

    -- Write both ledger legs and the transfer record in one statement.
    -- The CTEs return the new transaction IDs so the transfer can reference them.
    WITH debit_leg AS (
        INSERT INTO transactions (account_id, transaction_type, amount,
                                  balance_before, balance_after, channel,
                                  reference, narration, status)
        SELECT account_id, 'debit', 25000.00,
               balance + 25000.00, balance, 'mobile',
               'TXN-' || replace(gen_random_uuid()::text, '-', ''),
               'Transfer to Ngozi Eze', 'successful'
        FROM accounts
        WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
        RETURNING transaction_id
    ),
    credit_leg AS (
        INSERT INTO transactions (account_id, transaction_type, amount,
                                  balance_before, balance_after, channel,
                                  reference, narration, status)
        SELECT account_id, 'credit', 25000.00,
               balance - 25000.00, balance, 'mobile',
               'TXN-' || replace(gen_random_uuid()::text, '-', ''),
               'Transfer from Tunde Adeyemi', 'successful'
        FROM accounts
        WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000003'
        RETURNING transaction_id
    )
    INSERT INTO transfers (source_account_id, destination_account_id, amount, fee,
                           transfer_type, payment_reference, narration, status,
                           source_transaction_id, dest_transaction_id, completed_at)
    SELECT 'd4e5f6a7-0001-4000-8000-000000000001',
           'd4e5f6a7-0001-4000-8000-000000000003',
           25000.00, 0.00, 'intrabank',
           'TRF-' || replace(gen_random_uuid()::text, '-', ''),
           'Transfer to Ngozi Eze', 'successful',
           debit_leg.transaction_id, credit_leg.transaction_id, NOW()
    FROM debit_leg, credit_leg;

COMMIT;

-- Verify: 0012345001 = 224,950.00 and 0023456001 = 875,000.00
SELECT account_number, balance
FROM accounts
WHERE account_id IN ('d4e5f6a7-0001-4000-8000-000000000001',
                     'd4e5f6a7-0001-4000-8000-000000000003')
ORDER BY account_number;


-- ------------------------------------------------------------
-- A2: Failed Transfer → ROLLBACK
-- Atomicity + Consistency: the credit runs first and succeeds, then
-- the debit violates CHECK (balance >= 0). PostgreSQL aborts the
-- whole transaction, so the credit is undone as well.
-- EXPECTED ERROR: new row for relation "accounts" violates check
--                 constraint "accounts_balance_check"
-- ------------------------------------------------------------
BEGIN;

    UPDATE accounts                         -- succeeds
    SET balance = balance + 10000000.00, updated_at = NOW()
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000003';

    UPDATE accounts                         -- fails: would go negative
    SET balance = balance - 10000000.00, updated_at = NOW()
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';

ROLLBACK;

-- Verify: both balances are unchanged from after A1
-- (0012345001 = 224,950.00, 0023456001 = 875,000.00)
SELECT account_number, balance
FROM accounts
WHERE account_id IN ('d4e5f6a7-0001-4000-8000-000000000001',
                     'd4e5f6a7-0001-4000-8000-000000000003')
ORDER BY account_number;


-- ------------------------------------------------------------
-- A3: SAVEPOINT — Partial Rollback in a Batch
-- A batch opens new accounts. One row is a duplicate NUBAN. Without
-- a savepoint, that error would abort the entire batch; rolling back
-- to the savepoint discards only the bad row.
-- EXPECTED ERROR: duplicate key value violates unique constraint
--                 "accounts_account_number_key"
-- ------------------------------------------------------------
BEGIN;

    -- Item 1: valid new account for Ngozi Eze
    INSERT INTO accounts (account_id, customer_id, account_number, account_type,
                          currency, balance, branch_id)
    VALUES ('d4e5f6a7-0001-4000-8000-000000000006',
            'c3d4e5f6-0001-4000-8000-000000000002', '0023456002', 'current',
            'NGN', 0.00, 'a1b2c3d4-0001-4000-8000-000000000002');

    SAVEPOINT before_item_2;

    -- Item 2: duplicate account number (0012345001 already exists) → error
    INSERT INTO accounts (customer_id, account_number, account_type,
                          currency, balance, branch_id)
    VALUES ('c3d4e5f6-0001-4000-8000-000000000002', '0012345001', 'savings',
            'NGN', 0.00, 'a1b2c3d4-0001-4000-8000-000000000002');

    -- The transaction is now in an aborted state. Undo only item 2:
    ROLLBACK TO SAVEPOINT before_item_2;

    -- Item 3: valid, processed after recovering
    INSERT INTO accounts (account_id, customer_id, account_number, account_type,
                          currency, balance, branch_id)
    VALUES ('d4e5f6a7-0001-4000-8000-000000000007',
            'c3d4e5f6-0001-4000-8000-000000000002', '0023456003', 'domiciliary',
            'USD', 0.00, 'a1b2c3d4-0001-4000-8000-000000000002');

COMMIT;

-- Verify: Ngozi Eze now has 0023456001, 0023456002 and 0023456003
SELECT account_number, account_type, currency
FROM accounts
WHERE customer_id = 'c3d4e5f6-0001-4000-8000-000000000002'
ORDER BY account_number;


-- ============================================================
-- PART B: Transaction Isolation Levels
-- ============================================================
-- PostgreSQL accepts four levels; READ UNCOMMITTED behaves exactly
-- like READ COMMITTED, so dirty reads can never happen.
-- The anomalies only appear with TWO concurrent sessions. Each
-- block shows what Session 1 runs; the comment says what to run
-- in Session 2 (a second psql window) at the marked point.
-- A complete, step-numbered version of these experiments (lost
-- update, FOR UPDATE, REPEATABLE READ conflict and deadlock) is in
-- ONI_OGOKRISTI_301931440_P3_SessionA.sql and ONI_OGOKRISTI_301931440_P3_SessionB.sql.
-- ============================================================

-- ------------------------------------------------------------
-- B1: READ COMMITTED (default) — non-repeatable read is possible
-- ------------------------------------------------------------
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SELECT balance FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';
    -- >>> Session 2 now runs:
    --     UPDATE accounts SET balance = balance + 1000
    --     WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';
    -- Second read sees the new committed value (+1000): non-repeatable read.
    SELECT balance FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';
COMMIT;


-- ------------------------------------------------------------
-- B2: REPEATABLE READ — one snapshot for the whole transaction
-- Used for statement generation: the balance and the transaction
-- list must agree even while new payments arrive.
-- ------------------------------------------------------------
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    SELECT balance FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';
    -- >>> Session 2 updates and commits as in B1.
    SELECT transaction_type, amount, balance_after, created_at
    FROM transactions
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
    ORDER BY created_at DESC;
    -- Same value as the first read: Session 2's change is invisible here.
    SELECT balance FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';
    -- Note: if THIS transaction tried to UPDATE that row now, PostgreSQL
    -- would raise "could not serialize access due to concurrent update"
    -- and the application must retry.
COMMIT;


-- ------------------------------------------------------------
-- B3: SERIALIZABLE — end-of-day settlement
-- PostgreSQL implements SERIALIZABLE with Serializable Snapshot
-- Isolation (SSI): it tracks read/write dependencies and aborts one
-- transaction (SQLSTATE 40001) if the result could differ from some
-- serial order. The application must catch 40001 and retry.
-- ------------------------------------------------------------
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    SELECT currency, SUM(balance) AS total_deposits, COUNT(*) AS total_accounts
    FROM accounts
    WHERE status = 'active'
    GROUP BY currency;

    SELECT COUNT(*) AS total_transactions,
           SUM(amount) FILTER (WHERE transaction_type = 'credit') AS total_credits,
           SUM(amount) FILTER (WHERE transaction_type IN ('debit', 'fee')) AS total_debits
    FROM transactions
    WHERE created_at >= DATE '2026-11-01'
      AND created_at <  DATE '2026-11-02'
      AND status = 'successful';
COMMIT;


-- ============================================================
-- PART C: Concurrency Control
-- ============================================================

-- ------------------------------------------------------------
-- C1: Pessimistic Locking — SELECT ... FOR UPDATE
-- Prevents the "lost update": without the lock, two sessions could
-- both read 224,950, both subtract, and one debit would be lost.
-- A second session running the same block waits at the SELECT
-- until this transaction commits.
-- ------------------------------------------------------------
BEGIN;
    SELECT balance FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
    FOR UPDATE;

    UPDATE accounts
    SET balance = balance - 1000.00, updated_at = NOW()
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';

    INSERT INTO transactions (account_id, transaction_type, amount,
                              balance_before, balance_after, channel,
                              reference, narration, status)
    SELECT account_id, 'debit', 1000.00, balance + 1000.00, balance, 'atm',
           'TXN-' || replace(gen_random_uuid()::text, '-', ''),
           'ATM withdrawal', 'successful'
    FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';
COMMIT;


-- ------------------------------------------------------------
-- C2: FOR UPDATE SKIP LOCKED — parallel transfer workers
-- Several workers poll the queue of pending transfers. Each claims
-- one row; rows locked by another worker are skipped rather than
-- waited on, so workers never block each other or process the same
-- transfer twice. The seed data contains one pending PAPSS transfer.
-- ------------------------------------------------------------
BEGIN;
    UPDATE transfers
    SET status = 'processing'
    WHERE transfer_id = (
        SELECT transfer_id
        FROM transfers
        WHERE status = 'pending'
        ORDER BY created_at
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    )
    RETURNING transfer_id, payment_reference, amount, transfer_type, status;
    -- The worker would now call the PAPSS gateway, then set the
    -- status to 'successful' or 'failed' in a follow-up transaction.
COMMIT;


-- ------------------------------------------------------------
-- C3: Advisory Lock — only one end-of-day job at a time
-- pg_try_advisory_lock returns false instead of waiting, so a
-- second scheduler instance can log "already running" and exit.
-- ------------------------------------------------------------
SELECT pg_try_advisory_lock(1001) AS acquired_eod_lock;

    SELECT account_type, currency, COUNT(*) AS account_count,
           SUM(balance) AS total_balance
    FROM accounts
    WHERE status = 'active'
    GROUP BY account_type, currency
    ORDER BY account_type, currency;

SELECT pg_advisory_unlock(1001) AS released_eod_lock;


-- ------------------------------------------------------------
-- C4: Deadlock (run manually in two psql windows)
-- ------------------------------------------------------------
-- Session A                               Session B
-- BEGIN;                                  BEGIN;
-- UPDATE accounts SET balance=balance-100
--  WHERE account_id='...0001';  -- locks 1
--                                         UPDATE accounts SET balance=balance-200
--                                          WHERE account_id='...0003'; -- locks 3
-- UPDATE accounts SET balance=balance+100
--  WHERE account_id='...0003';  -- waits for B
--                                         UPDATE accounts SET balance=balance+200
--                                          WHERE account_id='...0001'; -- waits for A
--
-- After deadlock_timeout (1s by default) PostgreSQL detects the cycle
-- and aborts one session with "ERROR: deadlock detected"; the other
-- proceeds.
--
-- Prevention: A1 locks both accounts with ORDER BY account_id FOR UPDATE
-- before changing anything. When every transfer acquires locks in the
-- same order, a circular wait cannot form.


-- ============================================================
-- PART D: Lock Monitoring
-- ============================================================
-- Run in a third session while B1/C1/C4 are paused to see who holds
-- and who waits for which lock.
SELECT
    a.pid,
    l.locktype,
    l.relation::regclass AS table_name,
    l.mode,
    l.granted,
    pg_blocking_pids(a.pid) AS blocked_by,
    a.state,
    left(a.query, 60) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
WHERE l.relation IS NOT NULL
  AND a.pid <> pg_backend_pid()
ORDER BY a.pid, table_name;
