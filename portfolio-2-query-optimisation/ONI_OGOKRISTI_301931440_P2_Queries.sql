-- Find transfer records where occurred_at matches "2026-02-01T10:30:00+01:00" (up to 20).
SELECT * FROM portfolio."transfer"
WHERE "occurred_at" IS NOT DISTINCT FROM '2026-02-01T10:30:00+01:00'
ORDER BY "transfer_id"
LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM portfolio."transfer"
WHERE "occurred_at" IS NOT DISTINCT FROM '2026-02-01T10:30:00+01:00'
ORDER BY "transfer_id"
LIMIT 20;

-- Show related customer, account, transfer records (up to 20).
SELECT t0."customer_id" AS "customer_customer_id",
       t0."customer_ref" AS "customer_customer_ref",
       t1."account_id" AS "account_account_id",
       t1."account_number" AS "account_account_number",
       t2."transfer_id" AS "transfer_transfer_id",
       t2."reference" AS "transfer_reference"
FROM portfolio."customer" t0
JOIN portfolio."account" t1 ON t1."customer_id" = t0."customer_id"
JOIN portfolio."transfer" t2 ON t2."account_id" = t1."account_id"
ORDER BY t0."customer_id", t1."account_id", t2."transfer_id"
LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT t0."customer_id" AS "customer_customer_id",
       t0."customer_ref" AS "customer_customer_ref",
       t1."account_id" AS "account_account_id",
       t1."account_number" AS "account_account_number",
       t2."transfer_id" AS "transfer_transfer_id",
       t2."reference" AS "transfer_reference"
FROM portfolio."customer" t0
JOIN portfolio."account" t1 ON t1."customer_id" = t0."customer_id"
JOIN portfolio."transfer" t2 ON t2."account_id" = t1."account_id"
ORDER BY t0."customer_id", t1."account_id", t2."transfer_id"
LIMIT 20;

-- Count account records for each customer_id (up to 20 groups).
SELECT "customer_id", count(*) AS record_count
FROM portfolio."account"
GROUP BY "customer_id"
ORDER BY record_count DESC, "customer_id" NULLS LAST
LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT "customer_id", count(*) AS record_count
FROM portfolio."account"
GROUP BY "customer_id"
ORDER BY record_count DESC, "customer_id" NULLS LAST
LIMIT 20;
