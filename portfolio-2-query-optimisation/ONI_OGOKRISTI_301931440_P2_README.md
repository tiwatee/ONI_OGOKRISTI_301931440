# EgoTrust Transfer and Account Records — SQL queries

## 1. Find transfer records where occurred_at matches "2026-02-01T10:30:00+01:00" (up to 20).

```sql
SELECT * FROM portfolio."transfer"
WHERE "occurred_at" IS NOT DISTINCT FROM '2026-02-01T10:30:00+01:00'
ORDER BY "transfer_id"
LIMIT 20;
```

| transfer_id | account_id | reference | amount | channel | rail | status | occurred_at |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 301 | 201 | TRF-001 | 2500 | mobile | NIP | failed | 2026-02-01T09:30:00+00:00 |

## 2. Show related customer, account, transfer records (up to 20).

```sql
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
```

| customer_customer_id | customer_customer_ref | account_account_id | account_account_number | transfer_transfer_id | transfer_reference |
| --- | --- | --- | --- | --- | --- |
| 101 | CUS-001 | 201 | 1000000001 | 301 | TRF-001 |

## 3. Count account records for each customer_id (up to 20 groups).

```sql
SELECT "customer_id", count(*) AS record_count
FROM portfolio."account"
GROUP BY "customer_id"
ORDER BY record_count DESC, "customer_id" NULLS LAST
LIMIT 20;
```

| customer_id | record_count |
| --- | --- |
| 101 | 1 |


## Index comparison

| Phase | Median (ms) | Three runs (ms) | Plan nodes | Buffer hits |
| --- | --- | --- | --- | --- |
| Before index | 2.414 | 2.388, 2.414, 2.414 | Sort → Seq Scan | 274 |
| After index | 0.318 | 0.338, 0.318, 0.315 | Sort → Bitmap Heap Scan → Bitmap Index Scan | 55 |

The median execution time changed from 2.414 ms to 0.318 ms. The measured plan used p2_filter_idx. The results matched in both phases. An index adds storage and write-maintenance costs; timings depend on the selected lookup and environment.

## Execution plans

### Before index, run 1

```text
Sort (actual time=2.354..2.357 rows=50 loops=1)
  Seq Scan on transfer (actual time=0.016..2.317 rows=50 loops=1)
Planning Time: 0.328 ms
Execution Time: 2.388 ms
```

### Before index, run 2

```text
Sort (actual time=2.381..2.384 rows=50 loops=1)
  Seq Scan on transfer (actual time=0.017..2.341 rows=50 loops=1)
Planning Time: 0.362 ms
Execution Time: 2.414 ms
```

### Before index, run 3

```text
Sort (actual time=2.38..2.383 rows=50 loops=1)
  Seq Scan on transfer (actual time=0.016..2.345 rows=50 loops=1)
Planning Time: 0.334 ms
Execution Time: 2.414 ms
```

### After index, run 1

```text
Sort (actual time=0.272..0.275 rows=50 loops=1)
  Bitmap Heap Scan on transfer (actual time=0.037..0.234 rows=50 loops=1)
    Bitmap Index Scan using p2_filter_idx (actual time=0.02..0.02 rows=50 loops=1)
Planning Time: 0.519 ms
Execution Time: 0.338 ms
```

### After index, run 2

```text
Sort (actual time=0.254..0.257 rows=50 loops=1)
  Bitmap Heap Scan on transfer (actual time=0.037..0.216 rows=50 loops=1)
    Bitmap Index Scan using p2_filter_idx (actual time=0.02..0.02 rows=50 loops=1)
Planning Time: 0.547 ms
Execution Time: 0.318 ms
```

### After index, run 3

```text
Sort (actual time=0.253..0.256 rows=50 loops=1)
  Bitmap Heap Scan on transfer (actual time=0.037..0.215 rows=50 loops=1)
    Bitmap Index Scan using p2_filter_idx (actual time=0.019..0.02 rows=50 loops=1)
Planning Time: 0.548 ms
Execution Time: 0.315 ms
```

## Reproduce

Use a fresh database with the Portfolio 1 schema and sample data. Run ONI_OGOKRISTI_301931440_P2_Queries.sql, then ONI_OGOKRISTI_301931440_P2_Optimisation.sql. The optimisation script creates a separate performance table and runs EXPLAIN (ANALYZE, BUFFERS).

[Query screenshot](screenshots/ONI_OGOKRISTI_301931440_P2_QueryResults.png) · [Index comparison](screenshots/ONI_OGOKRISTI_301931440_P2_IndexComparison.png)

## References

- [PostgreSQL — EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html)

