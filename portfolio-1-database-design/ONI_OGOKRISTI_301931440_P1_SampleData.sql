-- ============================================================
-- EgoTrust — Sample Data (fictional records)
-- MIT 8103 Advanced Database Systems — Portfolio 1
-- Ogokristi Oni · Student ID 301931440
-- Run after ONI_OGOKRISTI_301931440_P1_Schema.sql, on a fresh database.
-- All names, BVNs and account numbers are invented.
-- ============================================================
BEGIN;

-- Balances are consistent: each account's balance equals the
-- balance_after of its latest successful transaction.

-- Branches
INSERT INTO branches (branch_id, branch_name, branch_code, address, city, state)
VALUES
    ('a1b2c3d4-0001-4000-8000-000000000001', 'Marina Branch', 'MRN001', '54 Marina Road', 'Lagos', 'Lagos'),
    ('a1b2c3d4-0001-4000-8000-000000000002', 'Ikeja Branch', 'IKJ002', '12 Allen Avenue', 'Lagos', 'Lagos'),
    ('a1b2c3d4-0001-4000-8000-000000000003', 'Abuja Main', 'ABJ003', '7 Wuse Zone 5', 'Abuja', 'FCT');

-- Staff
INSERT INTO staff (staff_id, branch_id, first_name, last_name, email, role)
VALUES
    ('b2c3d4e5-0001-4000-8000-000000000001', 'a1b2c3d4-0001-4000-8000-000000000001', 'Aisha', 'Bello', 'aisha.bello@egotrust.com', 'teller'),
    ('b2c3d4e5-0001-4000-8000-000000000002', 'a1b2c3d4-0001-4000-8000-000000000002', 'Chidi', 'Okonkwo', 'chidi.okonkwo@egotrust.com', 'branch_manager'),
    ('b2c3d4e5-0001-4000-8000-000000000003', 'a1b2c3d4-0001-4000-8000-000000000001', 'Kemi', 'Adebayo', 'kemi.adebayo@egotrust.com', 'compliance_officer');

-- Customers
INSERT INTO customers (customer_id, first_name, last_name, email, phone_number, bvn, date_of_birth, address, customer_type, created_at)
VALUES
    ('c3d4e5f6-0001-4000-8000-000000000001', 'Tunde', 'Adeyemi', 'tunde.adeyemi@email.com', '08012345678', '22345678901', '1990-05-15', '45 Lekki Phase 1, Lagos', 'retail', '2026-10-01 09:00'),
    ('c3d4e5f6-0001-4000-8000-000000000002', 'Ngozi', 'Eze', 'ngozi.eze@email.com', '08098765432', '22345678902', '1985-11-20', '10 GRA, Port Harcourt', 'retail', '2026-10-03 11:30'),
    ('c3d4e5f6-0001-4000-8000-000000000003', 'Fashola', 'Enterprises', 'info@fasholaent.com', '08055551234', '22345678903', '1975-01-01', '22 Broad Street, Lagos', 'sme', '2026-10-10 14:00');

-- KYC Documents
INSERT INTO kyc_documents (customer_id, document_type, document_number, verification_status, verified_by, verified_at)
VALUES
    ('c3d4e5f6-0001-4000-8000-000000000001', 'national_id', 'NIN-1234567890', 'verified', 'b2c3d4e5-0001-4000-8000-000000000003', '2026-10-01 10:00'),
    ('c3d4e5f6-0001-4000-8000-000000000001', 'utility_bill', 'UB-2024-0045', 'verified', 'b2c3d4e5-0001-4000-8000-000000000003', '2026-10-01 10:05'),
    ('c3d4e5f6-0001-4000-8000-000000000002', 'passport', 'A09876543', 'verified', 'b2c3d4e5-0001-4000-8000-000000000003', '2026-10-03 12:00'),
    ('c3d4e5f6-0001-4000-8000-000000000003', 'national_id', 'NIN-9876543210', 'pending', NULL, NULL);

-- Accounts
INSERT INTO accounts (account_id, customer_id, account_number, account_type, currency, balance, branch_id)
VALUES
    ('d4e5f6a7-0001-4000-8000-000000000001', 'c3d4e5f6-0001-4000-8000-000000000001', '0012345001', 'savings', 'NGN', 249950.00, 'a1b2c3d4-0001-4000-8000-000000000001'),
    ('d4e5f6a7-0001-4000-8000-000000000002', 'c3d4e5f6-0001-4000-8000-000000000001', '0012345002', 'current', 'NGN', 1500000.00, 'a1b2c3d4-0001-4000-8000-000000000001'),
    ('d4e5f6a7-0001-4000-8000-000000000003', 'c3d4e5f6-0001-4000-8000-000000000002', '0023456001', 'savings', 'NGN', 850000.00, 'a1b2c3d4-0001-4000-8000-000000000002'),
    ('d4e5f6a7-0001-4000-8000-000000000004', 'c3d4e5f6-0001-4000-8000-000000000003', '0034567001', 'current', 'NGN', 5199950.00, 'a1b2c3d4-0001-4000-8000-000000000003'),
    ('d4e5f6a7-0001-4000-8000-000000000005', 'c3d4e5f6-0001-4000-8000-000000000001', '0012345003', 'domiciliary', 'USD', 3200.00, 'a1b2c3d4-0001-4000-8000-000000000001');

-- Transactions (fixed IDs so transfers can reference their ledger legs)
INSERT INTO transactions (transaction_id, account_id, transaction_type, amount, balance_before, balance_after, channel, reference, narration, status, created_at)
VALUES
    ('e5f6a7b8-0001-4000-8000-000000000001', 'd4e5f6a7-0001-4000-8000-000000000001', 'credit', 50000.00, 200000.00, 250000.00, 'api', 'TXN-20261101-001', 'Salary credit Nov 2026', 'successful', '2026-11-01 08:30'),
    ('e5f6a7b8-0001-4000-8000-000000000002', 'd4e5f6a7-0001-4000-8000-000000000002', 'debit', 25000.00, 1525000.00, 1500000.00, 'web', 'TXN-20261101-002', 'Transfer to Ngozi Eze', 'successful', '2026-11-01 10:15'),
    ('e5f6a7b8-0001-4000-8000-000000000003', 'd4e5f6a7-0001-4000-8000-000000000003', 'credit', 25000.00, 825000.00, 850000.00, 'web', 'TXN-20261101-003', 'Transfer from Tunde Adeyemi', 'successful', '2026-11-01 10:15'),
    ('e5f6a7b8-0001-4000-8000-000000000004', 'd4e5f6a7-0001-4000-8000-000000000004', 'debit', 100000.00, 5300000.00, 5200000.00, 'branch', 'TXN-20261101-004', 'Vendor payment via NIP', 'successful', '2026-11-01 13:40'),
    ('e5f6a7b8-0001-4000-8000-000000000005', 'd4e5f6a7-0001-4000-8000-000000000004', 'fee', 50.00, 5200000.00, 5199950.00, 'branch', 'TXN-20261101-005', 'NIP transfer fee', 'successful', '2026-11-01 13:40'),
    ('e5f6a7b8-0001-4000-8000-000000000006', 'd4e5f6a7-0001-4000-8000-000000000001', 'fee', 50.00, 250000.00, 249950.00, 'api', 'TXN-20261101-006', 'SMS notification fee', 'successful', '2026-11-01 23:00');

-- Transfers
INSERT INTO transfers (transfer_id, source_account_id, destination_account_id,
                       beneficiary_bank_code, beneficiary_account_no, beneficiary_name,
                       amount, fee, transfer_type, payment_reference, narration, status,
                       failure_reason, session_id, source_transaction_id, dest_transaction_id,
                       created_at, completed_at)
VALUES
    -- Intrabank: both legs are EgoTrust ledger entries
    ('f6a7b8c9-0001-4000-8000-000000000001', 'd4e5f6a7-0001-4000-8000-000000000002', 'd4e5f6a7-0001-4000-8000-000000000003',
     NULL, NULL, NULL,
     25000.00, 0.00, 'intrabank', 'TRF-20261101-001', 'Transfer to Ngozi Eze', 'successful',
     NULL, NULL, 'e5f6a7b8-0001-4000-8000-000000000002', 'e5f6a7b8-0001-4000-8000-000000000003',
     '2026-11-01 10:15', '2026-11-01 10:15'),
    -- Interbank NIP: only the debit leg exists in our ledger
    ('f6a7b8c9-0001-4000-8000-000000000002', 'd4e5f6a7-0001-4000-8000-000000000004', NULL,
     '000013', '0198765432', 'Lagos Office Supplies Ltd',
     100000.00, 50.00, 'nip', 'TRF-20261101-002', 'Vendor payment via NIP', 'successful',
     NULL, '000013261101134000123456', 'e5f6a7b8-0001-4000-8000-000000000004', NULL,
     '2026-11-01 13:40', '2026-11-01 13:41'),
    -- Failed NIP: no money moved, so no ledger legs
    ('f6a7b8c9-0001-4000-8000-000000000003', 'd4e5f6a7-0001-4000-8000-000000000003', NULL,
     '000016', '3087654321', 'Chukwuma Obi',
     40000.00, 25.00, 'nip', 'TRF-20261102-003', 'Rent contribution', 'failed',
     'Beneficiary bank unavailable (NIP response 91)', '000016261102091500654321', NULL, NULL,
     '2026-11-02 09:15', NULL),
    -- Pending PAPSS: awaiting processing (used by the SKIP LOCKED demo in Portfolio 3)
    ('f6a7b8c9-0001-4000-8000-000000000004', 'd4e5f6a7-0001-4000-8000-000000000002', NULL,
     'GH-GCB01', '1020304050', 'Kwame Mensah',
     75000.00, 100.00, 'papss', 'TRF-20261102-004', 'Invoice settlement (Ghana)', 'pending',
     NULL, NULL, NULL, NULL,
     '2026-11-02 15:00', NULL);

-- Audit log
INSERT INTO audit_logs (staff_id, action, entity_type, entity_id, old_values, new_values, ip_address, created_at)
VALUES
    ('b2c3d4e5-0001-4000-8000-000000000001', 'account_freeze', 'account', 'd4e5f6a7-0001-4000-8000-000000000001',
     '{"status": "active"}', '{"status": "frozen"}', '192.168.1.100', '2026-11-03 09:00'),
    ('b2c3d4e5-0001-4000-8000-000000000002', 'account_unfreeze', 'account', 'd4e5f6a7-0001-4000-8000-000000000001',
     '{"status": "frozen"}', '{"status": "active"}', '192.168.1.120', '2026-11-03 16:30');

COMMIT;
