-- ============================================================
-- EgoTrust — Indexing and Query Optimisation Strategy
-- MIT 8103 Advanced Database Systems — Portfolio 2
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- Run after ONI_OGOKRISTI_301931440_P1_Schema.sql and ONI_OGOKRISTI_301931440_P1_SampleData.sql:
--   psql -U postgres -d egotrust -f ONI_OGOKRISTI_301931440_P2_Optimisation.sql
--
-- The seed data has only a handful of rows, and on tables that
-- small PostgreSQL will (correctly) choose a sequential scan
-- whatever indexes exist. To show the effect of indexing, this
-- script builds a separate 500,000-row benchmark table, measures
-- the plan before and after each index, and only then applies
-- the chosen indexes to the real tables.
-- ============================================================

\timing on

-- ============================================================
-- STEP 1: Baseline — existing indexes on the real schema
-- ============================================================
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;


-- ============================================================
-- STEP 2: Build a benchmark table with realistic volume
-- ============================================================
-- LIKE copies columns, defaults and CHECK constraints but no
-- indexes or foreign keys, so we start from a true "no index" state.
DROP TABLE IF EXISTS txn_benchmark;
CREATE TABLE txn_benchmark
    (LIKE transactions INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

-- 500,000 rows across 5,000 accounts (~100 rows per account),
-- spread over Sep–Dec 2026; ~95% successful, ~4% failed, ~1% pending.
INSERT INTO txn_benchmark (account_id, transaction_type, amount,
                           balance_before, balance_after, channel,
                           reference, narration, status, created_at)
SELECT
    ('d4e5f6a7-0001-4000-8000-' || lpad((g % 5000)::text, 12, '0'))::uuid,
    (ARRAY['credit','debit','fee'])[1 + g % 3],
    round((100 + random() * 99900)::numeric, 2),
    1000000.00,
    1000000.00,
    (ARRAY['mobile','web','ussd','pos','atm','branch','api'])[1 + g % 7],
    'BENCH-' || g,
    'Synthetic load-test transaction',
    CASE WHEN g % 100 < 95 THEN 'successful'
         WHEN g % 100 < 99 THEN 'failed'
         ELSE 'pending' END,
    TIMESTAMP '2026-09-01' + (random() * INTERVAL '120 days')
FROM generate_series(1, 500000) AS g;

VACUUM ANALYZE txn_benchmark;


-- ============================================================
-- STEP 3: Query 2 (account statement) — BEFORE indexing
-- ============================================================
-- Observed: Parallel Seq Scan, ~166,000 rows removed by filter per worker (33.1 ms).
EXPLAIN (ANALYZE, BUFFERS)
SELECT transaction_id, transaction_type, amount, balance_after,
       channel, reference, status, created_at
FROM txn_benchmark
WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
  AND status = 'successful'
  AND created_at >= '2026-11-01' AND created_at < '2026-12-01'
ORDER BY created_at DESC;


-- ============================================================
-- STEP 4: Composite index — AFTER indexing
-- ============================================================
-- Column order rule: equality columns first (account_id, status),
-- then the range/sort column (created_at). With created_at last the
-- index returns rows already in date order, so no Sort node is needed.
CREATE INDEX idx_bench_account_status_date
    ON txn_benchmark (account_id, status, created_at);
ANALYZE txn_benchmark;

-- Observed (PostgreSQL 16): Bitmap Index Scan on idx_bench_account_status_date
-- with all four predicates as Index Cond; ~22 rows read instead of 500,000.
-- In the recorded run execution time fell from 33.1 ms to 0.22 ms
-- (exact figures vary by machine and run).
EXPLAIN (ANALYZE, BUFFERS)
SELECT transaction_id, transaction_type, amount, balance_after,
       channel, reference, status, created_at
FROM txn_benchmark
WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
  AND status = 'successful'
  AND created_at >= '2026-11-01' AND created_at < '2026-12-01'
ORDER BY created_at DESC;


-- ------------------------------------------------------------
-- STEP 4b: Wrong column order, for comparison
-- ------------------------------------------------------------
-- With the range column in the middle, the scan must walk every index
-- entry for the account in the date range (all statuses) and test status
-- on each. With only ~100 rows per account the difference is negligible
-- here; it grows for busy accounts with thousands of rows per month,
-- which is why equality-first ordering is the rule.
DROP INDEX idx_bench_account_status_date;
CREATE INDEX idx_bench_account_date_status
    ON txn_benchmark (account_id, created_at, status);
ANALYZE txn_benchmark;

EXPLAIN (ANALYZE, BUFFERS)
SELECT transaction_id, transaction_type, amount, balance_after,
       channel, reference, status, created_at
FROM txn_benchmark
WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
  AND status = 'successful'
  AND created_at >= '2026-11-01' AND created_at < '2026-12-01'
ORDER BY created_at DESC;

DROP INDEX idx_bench_account_date_status;
CREATE INDEX idx_bench_account_status_date
    ON txn_benchmark (account_id, status, created_at);


-- ============================================================
-- STEP 5: Covering index → Index Only Scan
-- ============================================================
-- An index-only scan is possible only when EVERY column the query
-- reads (SELECT list and WHERE) is in the index. INCLUDE adds
-- payload columns to the index leaf pages without making them
-- part of the search key.
CREATE INDEX idx_bench_statement_totals
    ON txn_benchmark (account_id, status, created_at)
    INCLUDE (transaction_type, amount);
VACUUM ANALYZE txn_benchmark;   -- updates the visibility map

-- Observed: Index Only Scan using idx_bench_statement_totals, Heap Fetches: 0
EXPLAIN (ANALYZE, BUFFERS)
SELECT transaction_type, COUNT(*) AS n, SUM(amount) AS total
FROM txn_benchmark
WHERE account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
  AND status = 'successful'
  AND created_at >= '2026-11-01' AND created_at < '2026-12-01'
GROUP BY transaction_type;


-- ============================================================
-- STEP 6: Partial index — size trade-off
-- ============================================================
-- Failed transactions are ~4% of rows. A partial index stores only
-- those rows, so it is a fraction of the size of a full index.
CREATE INDEX idx_bench_failed_partial
    ON txn_benchmark (created_at DESC) WHERE status = 'failed';
ANALYZE txn_benchmark;

-- Observed: Index Scan using idx_bench_failed_partial
EXPLAIN (ANALYZE, BUFFERS)
SELECT reference, amount, created_at
FROM txn_benchmark
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 50;

-- For comparison, a full index that could serve the same query
CREATE INDEX idx_bench_status_full
    ON txn_benchmark (status, created_at DESC);

-- Observed: partial ≈ 456 kB vs full ≈ 19 MB (about 40x smaller).
-- Both serve this query equally fast; the partial index wins on
-- storage, cache footprint and write cost (95% of inserts skip it).
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE relname = 'txn_benchmark'
ORDER BY pg_relation_size(indexrelid) DESC;


-- ============================================================
-- STEP 7: Apply the chosen indexes to the real EgoTrust tables
-- ============================================================

-- Query 2 (account statements): equality columns first, then range
CREATE INDEX idx_txn_account_status_date
    ON transactions (account_id, status, created_at);

-- Query 3 (failed transfers): partial index, failures are rare
CREATE INDEX idx_transfers_failed
    ON transfers (created_at DESC)
    WHERE status = 'failed';

-- Query 4 (daily channel report): partial on successful rows only
CREATE INDEX idx_txn_successful_date_channel
    ON transactions (created_at, channel, transaction_type)
    WHERE status = 'successful';

-- Query 7 (audit trail): adds the sort column to the existing
-- (entity_type, entity_id) index, which then becomes redundant
CREATE INDEX idx_audit_entity_date
    ON audit_logs (entity_type, entity_id, created_at DESC);
DROP INDEX idx_audit_entity;

-- Query 5 (KYC compliance queue): partial index on pending documents
CREATE INDEX idx_kyc_pending
    ON kyc_documents (created_at)
    WHERE verification_status = 'pending';

ANALYZE transactions;
ANALYZE transfers;
ANALYZE audit_logs;
ANALYZE kyc_documents;


-- ============================================================
-- STEP 8: Re-check Query 2 on the real table
-- ============================================================
-- With only 6 rows, a Seq Scan is still expected: reading one
-- 8 KB page is cheaper than walking an index. This is the
-- cost-based optimiser working correctly, not a missing index.
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.transaction_id, t.transaction_type, t.amount, t.balance_after,
       t.channel, t.reference, t.status, t.created_at
FROM transactions t
WHERE t.account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
  AND t.status = 'successful'
  AND t.created_at >= '2026-11-01' AND t.created_at < '2026-12-01'
ORDER BY t.created_at DESC;


-- ============================================================
-- STEP 9: Index usage statistics
-- ============================================================
SELECT
    indexrelname AS index_name,
    relname AS table_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
ORDER BY relname, indexrelname;

-- Clean up the benchmark table (comment out to keep it for screenshots)
DROP TABLE txn_benchmark;
