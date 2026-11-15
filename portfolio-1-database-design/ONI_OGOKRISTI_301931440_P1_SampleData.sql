-- Fictional sample records for EgoTrust Transfer and Account Records.
BEGIN;
SET LOCAL standard_conforming_strings = on;
INSERT INTO portfolio."customer" ("customer_id", "customer_ref", "full_name", "kyc_status", "created_on") VALUES (101, 'CUS-001', 'Amina Example', 'verified', '2026-01-15');
INSERT INTO portfolio."account" ("account_id", "customer_id", "account_number", "account_type", "currency_code", "balance", "opened_on") VALUES (201, 101, '1000000001', 'savings', 'NGN', 12500.5, '2026-01-16');
INSERT INTO portfolio."transfer" ("transfer_id", "account_id", "reference", "amount", "channel", "rail", "status", "occurred_at") VALUES (301, 201, 'TRF-001', 2500, 'mobile', 'NIP', 'failed', '2026-02-01T10:30:00+01:00');
COMMIT;
