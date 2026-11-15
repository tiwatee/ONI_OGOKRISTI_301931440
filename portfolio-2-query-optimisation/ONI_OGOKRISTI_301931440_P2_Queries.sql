-- ============================================================
-- EgoTrust Digital Banking Platform — Query Processing & Optimisation
-- MIT 8103 Advanced Database Systems — Portfolio 2
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- This script contains practical SQL queries against the EgoTrust
-- schema, demonstrating query complexity, execution plans, and
-- optimisation through indexing.
-- ============================================================

-- ============================================================
-- QUERY 1: Customer Account Summary
-- Business use: Generate a customer dashboard showing all accounts
-- with their balances and transaction counts.
-- ============================================================
EXPLAIN ANALYZE
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.customer_type,
    a.account_number,
    a.account_type,
    a.currency,
    a.balance,
    COUNT(t.transaction_id) AS total_transactions,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'credit' THEN t.amount ELSE 0 END), 0) AS total_credits,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'debit' THEN t.amount ELSE 0 END), 0) AS total_debits
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
LEFT JOIN transactions t ON t.account_id = a.account_id
WHERE c.status = 'active'
GROUP BY c.customer_id, c.first_name, c.last_name, c.customer_type,
         a.account_number, a.account_type, a.currency, a.balance
ORDER BY a.balance DESC;


-- ============================================================
-- QUERY 2: Transaction History for an Account (Date Range)
-- Business use: Account statement generation within a date window.
-- ============================================================
EXPLAIN ANALYZE
SELECT
    t.transaction_id,
    t.transaction_type,
    t.amount,
    t.balance_before,
    t.balance_after,
    t.channel,
    t.reference,
    t.narration,
    t.status,
    t.created_at
FROM transactions t
WHERE t.account_id = 'd4e5f6a7-0001-4000-8000-000000000001'
  AND t.status = 'successful'
  AND t.created_at >= '2026-11-01'       -- half-open range: includes all of 30 Nov,
  AND t.created_at <  '2026-12-01'       -- which BETWEEN '...-11-30' would cut off at 00:00
ORDER BY t.created_at DESC;


-- ============================================================
-- QUERY 3: Failed Transfers Report (Compliance/Ops)
-- Business use: Operations team needs to review all failed
-- transfers with source customer and account details.
-- ============================================================
EXPLAIN ANALYZE
SELECT
    tr.transfer_id,
    tr.payment_reference,
    tr.amount,
    tr.fee,
    tr.transfer_type,
    tr.status,
    tr.failure_reason,
    tr.created_at,
    c.first_name || ' ' || c.last_name AS source_customer,
    sa.account_number AS source_account
FROM transfers tr
JOIN accounts sa ON sa.account_id = tr.source_account_id
JOIN customers c ON c.customer_id = sa.customer_id
WHERE tr.status = 'failed'
ORDER BY tr.created_at DESC;


-- ============================================================
-- QUERY 4: Daily Transaction Volume and Value by Channel
-- Business use: Dashboard metric — how much money moved through
-- each channel on a given day. (In production the literal date
-- would be CURRENT_DATE; a fixed date keeps results reproducible
-- against the seed data.)
-- ============================================================
EXPLAIN ANALYZE
SELECT
    t.channel,
    t.transaction_type,
    COUNT(*) AS transaction_count,
    SUM(t.amount) AS total_value,
    ROUND(AVG(t.amount), 2) AS avg_value,
    MIN(t.amount) AS min_value,
    MAX(t.amount) AS max_value
FROM transactions t
WHERE t.created_at >= DATE '2026-11-01'
  AND t.created_at <  DATE '2026-11-02'
  AND t.status = 'successful'
GROUP BY t.channel, t.transaction_type
ORDER BY total_value DESC;


-- ============================================================
-- QUERY 5: KYC Compliance Report — Customers with Incomplete KYC
-- Business use: Compliance officer needs to see which customers
-- have pending or no KYC documents.
-- ============================================================
EXPLAIN ANALYZE
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.phone_number,
    c.customer_type,
    c.created_at AS registration_date,
    COUNT(k.kyc_id) AS total_documents,
    COUNT(CASE WHEN k.verification_status = 'verified' THEN 1 END) AS verified_docs,
    COUNT(CASE WHEN k.verification_status = 'pending' THEN 1 END) AS pending_docs
FROM customers c
LEFT JOIN kyc_documents k ON k.customer_id = c.customer_id
WHERE c.status = 'active'
GROUP BY c.customer_id, c.first_name, c.last_name, c.phone_number,
         c.customer_type, c.created_at
HAVING COUNT(CASE WHEN k.verification_status = 'verified' THEN 1 END) = 0
ORDER BY c.created_at ASC;


-- ============================================================
-- QUERY 6: Top Customers by Transaction Volume (Subquery + Window)
-- Business use: Identify high-value customers for relationship
-- management, using window functions for ranking.
-- Restricted to NGN accounts: summing NGN and USD amounts together
-- would produce a meaningless total.
-- ============================================================
EXPLAIN ANALYZE
SELECT * FROM (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.customer_type,
        COUNT(t.transaction_id) AS txn_count,
        SUM(t.amount) AS total_amount,
        RANK() OVER (ORDER BY SUM(t.amount) DESC) AS volume_rank
    FROM customers c
    JOIN accounts a ON a.customer_id = c.customer_id
    JOIN transactions t ON t.account_id = a.account_id
    WHERE t.status = 'successful'
      AND a.currency = 'NGN'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.customer_type
) ranked
WHERE volume_rank <= 10;


-- ============================================================
-- QUERY 7: Audit Trail for a Specific Account
-- Business use: Compliance needs the full audit history of
-- changes made to a particular account.
-- ============================================================
EXPLAIN ANALYZE
SELECT
    al.log_id,
    al.action,
    al.old_values,
    al.new_values,
    al.created_at,
    s.first_name || ' ' || s.last_name AS performed_by,
    s.role AS staff_role,
    al.ip_address
FROM audit_logs al
JOIN staff s ON s.staff_id = al.staff_id
WHERE al.entity_type = 'account'
  AND al.entity_id = 'd4e5f6a7-0001-4000-8000-000000000001'
ORDER BY al.created_at DESC;
