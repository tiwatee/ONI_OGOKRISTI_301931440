-- Run these deliberately invalid statements one at a time, outside a transaction.
-- Each should fail at the named constraint; the sample rows should remain unchanged.

-- 1. customer pk duplicate. Expected: pk_customer, SQLSTATE 23505.
INSERT INTO portfolio."customer" ("customer_id", "customer_ref", "full_name", "kyc_status", "created_on")
VALUES (101, 'CUS-TEST-001', 'Test Customer', 'pending', '2026-02-02');

-- 2. customer unique duplicate. Expected: uq_customer_0, SQLSTATE 23505.
INSERT INTO portfolio."customer" ("customer_id", "customer_ref", "full_name", "kyc_status", "created_on")
VALUES (102, 'CUS-001', 'Test Customer', 'pending', '2026-02-02');

-- 3. customer not null. Expected: customer_ref, SQLSTATE 23502.
INSERT INTO portfolio."customer" ("customer_id", "customer_ref", "full_name", "kyc_status", "created_on")
VALUES (103, NULL, 'Test Customer', 'pending', '2026-02-02');

-- 4. account pk duplicate. Expected: pk_account, SQLSTATE 23505.
INSERT INTO portfolio."account" ("account_id", "customer_id", "account_number", "account_type", "currency_code", "balance", "opened_on")
VALUES (201, 101, '1000000002', 'current', 'NGN', 100, '2026-02-02');

-- 5. account unique duplicate. Expected: uq_account_0, SQLSTATE 23505.
INSERT INTO portfolio."account" ("account_id", "customer_id", "account_number", "account_type", "currency_code", "balance", "opened_on")
VALUES (202, 101, '1000000001', 'current', 'NGN', 100, '2026-02-02');

-- 6. account fk missing customer. Expected: fk_account_0, SQLSTATE 23503.
INSERT INTO portfolio."account" ("account_id", "customer_id", "account_number", "account_type", "currency_code", "balance", "opened_on")
VALUES (203, 99901, '1000000003', 'current', 'NGN', 100, '2026-02-02');

-- 7. account negative balance. Expected: account_balance_nonnegative, SQLSTATE 23514.
INSERT INTO portfolio."account" ("account_id", "customer_id", "account_number", "account_type", "currency_code", "balance", "opened_on")
VALUES (204, 101, '1000000004', 'current', 'NGN', -1, '2026-02-02');

-- 8. transfer pk duplicate. Expected: pk_transfer, SQLSTATE 23505.
INSERT INTO portfolio."transfer" ("transfer_id", "account_id", "reference", "amount", "channel", "rail", "status", "occurred_at")
VALUES (301, 201, 'TRF-TEST-001', 100, 'mobile', 'NIP', 'failed', '2026-02-02T10:30:00+01:00');

-- 9. transfer unique duplicate. Expected: uq_transfer_0, SQLSTATE 23505.
INSERT INTO portfolio."transfer" ("transfer_id", "account_id", "reference", "amount", "channel", "rail", "status", "occurred_at")
VALUES (302, 201, 'TRF-001', 100, 'mobile', 'NIP', 'failed', '2026-02-02T10:30:00+01:00');

-- 10. transfer fk missing account. Expected: fk_transfer_0, SQLSTATE 23503.
INSERT INTO portfolio."transfer" ("transfer_id", "account_id", "reference", "amount", "channel", "rail", "status", "occurred_at")
VALUES (303, 99902, 'TRF-TEST-002', 100, 'mobile', 'NIP', 'failed', '2026-02-02T10:30:00+01:00');

-- 11. transfer zero amount. Expected: transfer_amount_positive, SQLSTATE 23514.
INSERT INTO portfolio."transfer" ("transfer_id", "account_id", "reference", "amount", "channel", "rail", "status", "occurred_at")
VALUES (304, 201, 'TRF-TEST-003', 0, 'mobile', 'NIP', 'failed', '2026-02-02T10:30:00+01:00');
