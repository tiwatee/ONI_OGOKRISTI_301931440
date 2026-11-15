-- ============================================================
-- EgoTrust Digital Banking Platform — PostgreSQL Schema (DDL)
-- MIT 8103 Advanced Database Systems — Portfolio 1
-- Ogokristi Oni · Student ID 301931440
-- ============================================================
-- Run on an empty database, before the sample data:
--   psql -U postgres -c "CREATE DATABASE egotrust;"
--   psql -U postgres -d egotrust -f ONI_OGOKRISTI_301931440_P1_Schema.sql
--   psql -U postgres -d egotrust -f ONI_OGOKRISTI_301931440_P1_SampleData.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Note on indexes: PostgreSQL automatically creates a unique B-tree
-- index for every PRIMARY KEY and UNIQUE constraint, so those columns
-- (bvn, phone_number, account_number, reference, payment_reference)
-- are NOT indexed again below. Explicit indexes are added only for
-- foreign keys and common filter columns, which PostgreSQL does not
-- index automatically.

-- ============================================================
-- 1. BRANCHES
-- ============================================================
CREATE TABLE branches (
    branch_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_name     VARCHAR(100)    NOT NULL,
    branch_code     VARCHAR(10)     NOT NULL UNIQUE,
    address         VARCHAR(255)    NOT NULL,
    city            VARCHAR(100)    NOT NULL,
    state           VARCHAR(100)    NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'inactive', 'closed')),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. STAFF
-- ============================================================
CREATE TABLE staff (
    staff_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id       UUID            NOT NULL
                        REFERENCES branches(branch_id),
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    role            VARCHAR(50)     NOT NULL
                        CHECK (role IN ('teller', 'relationship_manager',
                                        'compliance_officer', 'branch_manager',
                                        'admin')),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'suspended', 'terminated')),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_staff_branch ON staff(branch_id);

-- ============================================================
-- 3. CUSTOMERS
-- ============================================================
CREATE TABLE customers (
    customer_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    phone_number    VARCHAR(20)     NOT NULL UNIQUE,
    bvn             VARCHAR(11)     NOT NULL UNIQUE           -- Bank Verification Number
                        CHECK (bvn ~ '^[0-9]{11}$'),
    date_of_birth   DATE            NOT NULL,
    address         VARCHAR(255),
    customer_type   VARCHAR(20)     NOT NULL DEFAULT 'retail'
                        CHECK (customer_type IN ('retail', 'sme', 'corporate')),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'inactive', 'blocked', 'dormant')),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. KYC_DOCUMENTS
-- ============================================================
CREATE TABLE kyc_documents (
    kyc_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id         UUID            NOT NULL
                            REFERENCES customers(customer_id),
    document_type       VARCHAR(50)     NOT NULL
                            CHECK (document_type IN ('national_id', 'passport',
                                                     'drivers_license', 'voters_card',
                                                     'utility_bill')),
    document_number     VARCHAR(50)     NOT NULL,
    verification_status VARCHAR(20)     NOT NULL DEFAULT 'pending'
                            CHECK (verification_status IN ('pending', 'verified',
                                                           'rejected', 'expired')),
    verified_by         UUID
                            REFERENCES staff(staff_id),      -- staff who verified it
    verified_at         TIMESTAMP,
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW(),

    UNIQUE (customer_id, document_type),  -- one document per type per customer
    -- A verified document must record who verified it and when
    CHECK (verification_status <> 'verified'
           OR (verified_by IS NOT NULL AND verified_at IS NOT NULL))
);
-- (customer_id) lookups are served by the UNIQUE (customer_id, document_type) index.
CREATE INDEX idx_kyc_verified_by ON kyc_documents(verified_by);

-- ============================================================
-- 5. ACCOUNTS
-- ============================================================
CREATE TABLE accounts (
    account_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID            NOT NULL
                        REFERENCES customers(customer_id),
    account_number  VARCHAR(10)     NOT NULL UNIQUE            -- NUBAN
                        CHECK (account_number ~ '^[0-9]{10}$'),
    account_type    VARCHAR(20)     NOT NULL
                        CHECK (account_type IN ('savings', 'current', 'domiciliary')),
    currency        VARCHAR(3)      NOT NULL DEFAULT 'NGN'
                        CHECK (currency IN ('NGN', 'USD', 'GBP', 'EUR')),
    balance         DECIMAL(18, 2)  NOT NULL DEFAULT 0.00
                        CHECK (balance >= 0),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'frozen', 'closed', 'dormant')),
    branch_id       UUID            NOT NULL
                        REFERENCES branches(branch_id),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW(),

    -- Naira accounts cannot be domiciliary; domiciliary accounts hold foreign currency
    CHECK ((account_type = 'domiciliary') = (currency <> 'NGN'))
);

CREATE INDEX idx_accounts_customer ON accounts(customer_id);
CREATE INDEX idx_accounts_branch ON accounts(branch_id);

-- ============================================================
-- 6. TRANSACTIONS (ledger — immutable records)
-- ============================================================
CREATE TABLE transactions (
    transaction_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id      UUID            NOT NULL
                        REFERENCES accounts(account_id),
    transaction_type VARCHAR(20)    NOT NULL
                        CHECK (transaction_type IN ('credit', 'debit', 'reversal', 'fee')),
    amount          DECIMAL(18, 2)  NOT NULL
                        CHECK (amount > 0),
    balance_before  DECIMAL(18, 2)  NOT NULL,
    balance_after   DECIMAL(18, 2)  NOT NULL,
    channel         VARCHAR(30)     NOT NULL
                        CHECK (channel IN ('mobile', 'web', 'ussd', 'pos',
                                           'atm', 'branch', 'api')),
    reference       VARCHAR(50)     NOT NULL UNIQUE,
    narration       VARCHAR(255),
    status          VARCHAR(20)     NOT NULL DEFAULT 'successful'
                        CHECK (status IN ('successful', 'failed', 'pending', 'reversed')),
    -- Self-reference: a 'reversal' entry points at the transaction it reverses
    reverses_transaction_id UUID
                        REFERENCES transactions(transaction_id),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),

    CHECK ((transaction_type = 'reversal') = (reverses_transaction_id IS NOT NULL))
);

CREATE INDEX idx_txn_account ON transactions(account_id);
CREATE INDEX idx_txn_created ON transactions(created_at);
CREATE INDEX idx_txn_reverses ON transactions(reverses_transaction_id);

-- ============================================================
-- 7. TRANSFERS (fund movement between accounts)
-- ============================================================
CREATE TABLE transfers (
    transfer_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_account_id       UUID            NOT NULL
                                REFERENCES accounts(account_id),
    destination_account_id  UUID
                                REFERENCES accounts(account_id),  -- NULL for interbank
    -- Beneficiary details for interbank (NIP / PAPSS) transfers, where the
    -- destination account lives at another bank and has no row in `accounts`
    beneficiary_bank_code   VARCHAR(10),
    beneficiary_account_no  VARCHAR(20),
    beneficiary_name        VARCHAR(150),
    amount                  DECIMAL(18, 2)  NOT NULL
                                CHECK (amount > 0),
    fee                     DECIMAL(18, 2)  NOT NULL DEFAULT 0.00
                                CHECK (fee >= 0),
    currency                VARCHAR(3)      NOT NULL DEFAULT 'NGN'
                                CHECK (currency IN ('NGN', 'USD', 'GBP', 'EUR')),
    transfer_type           VARCHAR(20)     NOT NULL
                                CHECK (transfer_type IN ('intrabank', 'nip', 'papss')),
    payment_reference       VARCHAR(50)     NOT NULL UNIQUE,
    narration               VARCHAR(255),
    status                  VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'processing', 'successful',
                                                  'failed', 'reversed')),
    failure_reason          VARCHAR(255),
    session_id              VARCHAR(30),                        -- NIP/PAPSS session ID
    source_transaction_id   UUID UNIQUE
                                REFERENCES transactions(transaction_id),  -- debit leg
    dest_transaction_id     UUID UNIQUE
                                REFERENCES transactions(transaction_id),  -- credit leg (intrabank only)
    created_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    completed_at            TIMESTAMP,

    -- An account cannot transfer to itself
    CHECK (source_account_id <> destination_account_id),
    -- Intrabank: destination must be an EgoTrust account.
    -- Interbank: destination is external, so beneficiary details are required.
    CHECK (
        (transfer_type = 'intrabank' AND destination_account_id IS NOT NULL)
        OR
        (transfer_type IN ('nip', 'papss') AND destination_account_id IS NULL
         AND beneficiary_bank_code IS NOT NULL
         AND beneficiary_account_no IS NOT NULL)
    ),
    -- A failed transfer must say why
    CHECK (status <> 'failed' OR failure_reason IS NOT NULL)
);

CREATE INDEX idx_transfers_source ON transfers(source_account_id);
CREATE INDEX idx_transfers_dest ON transfers(destination_account_id);
CREATE INDEX idx_transfers_status ON transfers(status);

-- ============================================================
-- 8. AUDIT_LOGS (compliance / change tracking)
-- ============================================================
-- entity_type + entity_id is a polymorphic reference (it can point at an
-- account, customer, transfer, ...). A single FK cannot target several
-- tables, so this link is enforced by the application, not the database.
-- This is a documented trade-off for a generic audit trail.
CREATE TABLE audit_logs (
    log_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_id        UUID
                        REFERENCES staff(staff_id),            -- NULL = system action
    action          VARCHAR(50)     NOT NULL,                  -- e.g., 'account_freeze'
    entity_type     VARCHAR(50)     NOT NULL
                        CHECK (entity_type IN ('customer', 'account', 'transfer',
                                               'transaction', 'kyc_document', 'staff')),
    entity_id       UUID            NOT NULL,
    old_values      JSONB,
    new_values      JSONB,
    ip_address      INET,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_staff ON audit_logs(staff_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at);
