-- ============================================================
-- EgoTrust — Replication and Distributed Database Queries
-- MIT 8103 Advanced Database Systems — Portfolio 5
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- These queries demonstrate replication monitoring, read/write
-- routing, and distributed query patterns for EgoTrust.
-- ============================================================


-- ============================================================
-- PART A: Replication Status Monitoring
-- ============================================================

-- A1: Check if current instance is primary or replica
SELECT
    pg_is_in_recovery() AS is_replica,
    CASE
        WHEN pg_is_in_recovery() THEN 'READ REPLICA'
        ELSE 'PRIMARY'
    END AS instance_role;


-- A2: Monitor replication lag (run on REPLICA)
-- Shows how far behind the replica is from the primary
SELECT
    now() - pg_last_xact_replay_timestamp() AS replication_lag,
    pg_last_wal_receive_lsn() AS last_wal_received,
    pg_last_wal_replay_lsn() AS last_wal_replayed,
    CASE
        WHEN NOT pg_is_in_recovery()
        THEN 'N/A: this server is the primary'
        WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn()
        THEN 'FULLY CAUGHT UP'
        ELSE 'REPLAYING WAL'
    END AS sync_status;


-- A3: Monitor replication slots (run on PRIMARY)
-- restart_lsn is used because confirmed_flush_lsn is only populated
-- for LOGICAL slots; physical streaming-replica slots leave it NULL.
-- retained_wal shows how much WAL the primary is holding for each
-- replica (a stalled replica makes this grow until the disk fills).
SELECT
    slot_name,
    slot_type,
    active,
    restart_lsn,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots;


-- A4: Check connected replicas (run on PRIMARY)
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes,
    sync_state
FROM pg_stat_replication;


-- ============================================================
-- PART B: Read/Write Routing Patterns
-- ============================================================

-- B1: Write operation — MUST go to PRIMARY
-- Application connection string targets the primary endpoint
-- e.g., egotrust-primary.cluster-abc123.af-south-1.rds.amazonaws.com
-- The balance change and its ledger entry are written together,
-- so the stored balance never drifts from the ledger.
BEGIN;
    UPDATE accounts
    SET balance = balance - 10000.00,
        updated_at = NOW()
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';

    INSERT INTO transactions (account_id, transaction_type, amount,
                              balance_before, balance_after, channel,
                              reference, narration, status)
    SELECT account_id, 'debit', 10000.00, balance + 10000.00, balance, 'ussd',
           'TXN-' || replace(gen_random_uuid()::text, '-', ''),
           'Airtime purchase', 'successful'
    FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001';
COMMIT;


-- B2: Read operation — can go to REPLICA
-- Application connection string targets the reader endpoint
-- e.g., egotrust-reader.cluster-abc123.af-south-1.rds.amazonaws.com
-- Generates an account statement from read replica (no write load on primary)
SELECT
    t.created_at::date AS transaction_date,
    t.transaction_type,
    t.narration,
    t.amount,
    t.balance_after,
    t.channel,
    t.reference
FROM transactions t
WHERE t.account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
  AND t.created_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY t.created_at DESC;


-- B3: Critical read — MUST go to PRIMARY (balance before transfer)
-- Before initiating a transfer, the real-time balance must come from
-- the primary: a replica may lag and show money that has already been
-- spent. FOR UPDATE also cannot run on a read replica at all (replicas
-- are read-only), which enforces the routing rule.
-- The lock only lasts as long as the transaction, so it must be inside
-- BEGIN ... COMMIT together with the debit it protects.
BEGIN;
    SELECT balance
    FROM accounts
    WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
    FOR UPDATE;
    -- ... application checks the balance, then debits (as in Portfolio 3, A1)
COMMIT;


-- ============================================================
-- PART C: Partitioning (Preparation for Sharding)
-- ============================================================
-- PostgreSQL native partitioning prepares the schema for
-- distribution. Transactions are partitioned by month for
-- efficient archival and range queries.

-- C1: Create partitioned transaction table
-- Same columns and rules as `transactions`. On a partitioned table,
-- every PRIMARY KEY / UNIQUE constraint must include the partition
-- key, hence (transaction_id, created_at) and (reference, created_at).
CREATE TABLE IF NOT EXISTS transactions_partitioned (
    transaction_id   UUID           NOT NULL DEFAULT gen_random_uuid(),
    account_id       UUID           NOT NULL REFERENCES accounts(account_id),
    transaction_type VARCHAR(20)    NOT NULL
                         CHECK (transaction_type IN ('credit', 'debit', 'reversal', 'fee')),
    amount           DECIMAL(18,2)  NOT NULL CHECK (amount > 0),
    balance_before   DECIMAL(18,2)  NOT NULL,
    balance_after    DECIMAL(18,2)  NOT NULL,
    channel          VARCHAR(30)    NOT NULL,
    reference        VARCHAR(50)    NOT NULL,
    narration        VARCHAR(255),
    status           VARCHAR(20)    NOT NULL DEFAULT 'successful',
    created_at       TIMESTAMP      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (transaction_id, created_at),
    UNIQUE (reference, created_at)
) PARTITION BY RANGE (created_at);


-- C2: Create monthly partitions
CREATE TABLE IF NOT EXISTS txn_2026_10
    PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE IF NOT EXISTS txn_2026_11
    PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');

CREATE TABLE IF NOT EXISTS txn_2026_12
    PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Catch-all so an insert outside the defined months does not fail
CREATE TABLE IF NOT EXISTS txn_default
    PARTITION OF transactions_partitioned DEFAULT;

-- Archival: an old month can be detached in one cheap metadata
-- operation instead of a slow DELETE of millions of rows, e.g.
--   ALTER TABLE transactions_partitioned DETACH PARTITION txn_2026_10;


-- C3: Insert into partitioned table (PostgreSQL routes automatically)
INSERT INTO transactions_partitioned (
    account_id, transaction_type, amount,
    balance_before, balance_after,
    channel, reference, narration, status, created_at
) VALUES (
    'd4e5f6a7-0001-4000-8000-000000000001',
    'debit', 5000.00, 500000.00, 495000.00,
    'mobile', 'PART-TEST-001',
    'Partitioning test transaction',
    'successful', '2026-11-05 10:30:00'
);

-- C4: Partition pruning — the plan scans only txn_2026_11
EXPLAIN (ANALYZE)
SELECT * FROM transactions_partitioned
WHERE created_at >= '2026-11-01' AND created_at < '2026-12-01';


-- ============================================================
-- PART D: Connection Pooling Configuration (PgBouncer)
-- ============================================================
-- In a distributed environment, connection pooling is critical
-- to manage hundreds of application connections efficiently.

-- Check current connection usage
SELECT
    datname AS database,
    numbackends AS active_connections,
    xact_commit AS transactions_committed,
    xact_rollback AS transactions_rolled_back,
    blks_read AS disk_blocks_read,
    blks_hit AS cache_hits,
    ROUND(
        blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 2
    ) AS cache_hit_ratio
FROM pg_stat_database
WHERE datname = 'egotrust';
