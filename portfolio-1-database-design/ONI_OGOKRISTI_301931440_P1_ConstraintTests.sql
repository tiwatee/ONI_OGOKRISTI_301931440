-- ============================================================
-- EgoTrust — Constraint Tests
-- MIT 8103 Advanced Database Systems — Portfolio 1
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- Run after the schema and sample data. Every statement below is
-- deliberately invalid and MUST be rejected. psql runs each one in
-- autocommit mode, so a failure does not affect the next test, and
-- the sample data is left unchanged.
--   psql -U postgres -d egotrust -f ONI_OGOKRISTI_301931440_P1_ConstraintTests.sql
-- Expected: 18 ERROR lines, then the row-count check at the end.
-- ============================================================

-- ---------- Keys ----------

-- T01 Duplicate primary key (branch). Expected: branches_pkey, SQLSTATE 23505
INSERT INTO branches (branch_id, branch_name, branch_code, address, city, state)
VALUES ('a1b2c3d4-0001-4000-8000-000000000001', 'Duplicate', 'DUP001', 'x', 'Lagos', 'Lagos');

-- T02 Duplicate BVN (candidate key). Expected: customers_bvn_key, 23505
INSERT INTO customers (first_name, last_name, email, phone_number, bvn, date_of_birth)
VALUES ('Test', 'User', 'test1@email.com', '08000000001', '22345678901', '1990-01-01');

-- T03 Duplicate NUBAN account number. Expected: accounts_account_number_key, 23505
INSERT INTO accounts (customer_id, account_number, account_type, branch_id)
VALUES ('c3d4e5f6-0001-4000-8000-000000000002', '0012345001', 'savings',
        'a1b2c3d4-0001-4000-8000-000000000002');

-- T04 Second KYC document of the same type for one customer.
-- Expected: kyc_documents_customer_id_document_type_key, 23505
INSERT INTO kyc_documents (customer_id, document_type, document_number)
VALUES ('c3d4e5f6-0001-4000-8000-000000000001', 'national_id', 'NIN-0000000000');

-- T05 Duplicate transfer payment reference (duplicate-submission protection).
-- Expected: transfers_payment_reference_key, 23505
INSERT INTO transfers (source_account_id, destination_account_id, amount, transfer_type, payment_reference)
VALUES ('d4e5f6a7-0001-4000-8000-000000000002', 'd4e5f6a7-0001-4000-8000-000000000003',
        100, 'intrabank', 'TRF-20261101-001');

-- ---------- Referential integrity ----------

-- T06 Account for a customer that does not exist. Expected: accounts_customer_id_fkey, 23503
INSERT INTO accounts (customer_id, account_number, account_type, branch_id)
VALUES ('00000000-0000-4000-8000-000000000000', '0099999901', 'savings',
        'a1b2c3d4-0001-4000-8000-000000000001');

-- T07 Ledger entry for an account that does not exist. Expected: transactions_account_id_fkey, 23503
INSERT INTO transactions (account_id, transaction_type, amount, balance_before, balance_after, channel, reference)
VALUES ('00000000-0000-4000-8000-000000000000', 'credit', 100, 0, 100, 'api', 'TXN-TEST-T07');

-- T08 Deleting a customer who still has KYC documents and accounts.
-- Expected: kyc_documents_customer_id_fkey (the first FK checked), 23503
DELETE FROM customers WHERE customer_id = 'c3d4e5f6-0001-4000-8000-000000000002';

-- ---------- Domain rules (CHECK) ----------

-- T09 Negative balance (no overdraft). Expected: accounts_balance_check, 23514
UPDATE accounts SET balance = -1 WHERE account_number = '0012345001';

-- T10 BVN that is not 11 digits. Expected: customers_bvn_check, 23514
INSERT INTO customers (first_name, last_name, email, phone_number, bvn, date_of_birth)
VALUES ('Test', 'User', 'test2@email.com', '08000000002', '12345', '1990-01-01');

-- T11 Invalid KYC status value. Expected: kyc_documents_verification_status_check, 23514
UPDATE kyc_documents SET verification_status = 'banana' WHERE document_number = 'NIN-9876543210';

-- T12 Unsupported currency. Expected: accounts_currency_check, 23514
INSERT INTO accounts (customer_id, account_number, account_type, currency, branch_id)
VALUES ('c3d4e5f6-0001-4000-8000-000000000002', '0099999902', 'domiciliary', 'XYZ',
        'a1b2c3d4-0001-4000-8000-000000000002');

-- T13 Invalid transfer status. Expected: transfers_status_check, 23514
UPDATE transfers SET status = 'maybe' WHERE payment_reference = 'TRF-20261101-001';

-- T14 Zero transaction amount. Expected: transactions_amount_check, 23514
INSERT INTO transactions (account_id, transaction_type, amount, balance_before, balance_after, channel, reference)
VALUES ('d4e5f6a7-0001-4000-8000-000000000001', 'credit', 0, 249950, 249950, 'api', 'TXN-TEST-T14');

-- ---------- Cross-column business rules (CHECK) ----------

-- T15 Naira account marked domiciliary. Expected: accounts_check, 23514
INSERT INTO accounts (customer_id, account_number, account_type, currency, branch_id)
VALUES ('c3d4e5f6-0001-4000-8000-000000000002', '0099999903', 'domiciliary', 'NGN',
        'a1b2c3d4-0001-4000-8000-000000000002');

-- T16 NIP (interbank) transfer without beneficiary bank details. Expected: transfers_check1, 23514
INSERT INTO transfers (source_account_id, amount, transfer_type, payment_reference)
VALUES ('d4e5f6a7-0001-4000-8000-000000000001', 100, 'nip', 'TRF-TEST-T16');

-- T17 Transfer from an account to itself. Expected: transfers_check, 23514
INSERT INTO transfers (source_account_id, destination_account_id, amount, transfer_type, payment_reference)
VALUES ('d4e5f6a7-0001-4000-8000-000000000001', 'd4e5f6a7-0001-4000-8000-000000000001',
        100, 'intrabank', 'TRF-TEST-T17');

-- T18 KYC document marked verified with no verifying staff member. Expected: kyc_documents_check, 23514
UPDATE kyc_documents SET verification_status = 'verified'
WHERE document_number = 'NIN-9876543210';

-- ---------- Check: sample data unchanged ----------
-- Expected: 3 branches, 3 staff, 3 customers, 4 kyc, 5 accounts,
--           6 transactions, 4 transfers, 2 audit logs
SELECT 'branches' AS table_name, COUNT(*) AS row_count FROM branches
UNION ALL SELECT 'staff', COUNT(*) FROM staff
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'kyc_documents', COUNT(*) FROM kyc_documents
UNION ALL SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL SELECT 'transfers', COUNT(*) FROM transfers
UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;
