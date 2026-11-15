# EgoTrust — ER Diagram

Ogokristi Oni · Student ID 301931440 · MIT 8103 Portfolio 1

![EgoTrust ER diagram](../images/ONI_OGOKRISTI_301931440_ERDiagram.png)

The image above is rendered from the Mermaid source below; GitHub also renders the source directly.

**Notation:** `||` exactly one · `|o` zero or one · `o{` zero or many. PK primary key, FK foreign key, UK unique key.

```mermaid
erDiagram
  direction LR
  %% Cardinality legend:  ||  exactly one   |o  zero or one   |{  one or more   o{  zero or more
  CUSTOMERS     ||--o{ ACCOUNTS       : owns
  CUSTOMERS     ||--o{ KYC_DOCUMENTS  : submits
  BRANCHES      ||--o{ ACCOUNTS       : hosts
  BRANCHES      ||--o{ STAFF          : employs
  STAFF         |o--o{ KYC_DOCUMENTS  : verifies
  STAFF         |o--o{ AUDIT_LOGS     : performs
  ACCOUNTS      ||--o{ TRANSACTIONS   : "records (ledger)"
  ACCOUNTS      ||--o{ TRANSFERS      : "sends (source)"
  ACCOUNTS      |o--o{ TRANSFERS      : "receives (destination, intrabank only)"
  TRANSACTIONS  |o--o| TRANSFERS      : "debit leg"
  TRANSACTIONS  |o--o| TRANSFERS      : "credit leg (intrabank only)"
  TRANSACTIONS  |o--o| TRANSACTIONS   : "reversed by"

  CUSTOMERS {
    uuid customer_id PK
    varchar first_name
    varchar last_name
    varchar email UK
    varchar phone_number UK
    varchar bvn UK
    date date_of_birth
    varchar address
    varchar customer_type
    varchar status
    timestamp created_at
    timestamp updated_at
  }

  ACCOUNTS {
    uuid account_id PK
    uuid customer_id FK
    uuid branch_id FK
    varchar account_number UK "NUBAN"
    varchar account_type
    varchar currency
    decimal balance "CHECK >= 0"
    varchar status
    timestamp created_at
    timestamp updated_at
  }

  BRANCHES {
    uuid branch_id PK
    varchar branch_name
    varchar branch_code UK
    varchar address
    varchar city
    varchar state
    varchar status
    timestamp created_at
  }

  STAFF {
    uuid staff_id PK
    uuid branch_id FK
    varchar first_name
    varchar last_name
    varchar email UK
    varchar role
    varchar status
    timestamp created_at
  }

  KYC_DOCUMENTS {
    uuid kyc_id PK
    uuid customer_id FK "UK with document_type"
    varchar document_type
    varchar document_number
    varchar verification_status
    uuid verified_by FK
    timestamp verified_at
    timestamp created_at
  }

  TRANSACTIONS {
    uuid transaction_id PK
    uuid account_id FK
    varchar transaction_type
    decimal amount
    decimal balance_before
    decimal balance_after
    varchar channel
    varchar reference UK
    varchar narration
    varchar status
    uuid reverses_transaction_id FK "self-reference"
    timestamp created_at
  }

  TRANSFERS {
    uuid transfer_id PK
    uuid source_account_id FK
    uuid destination_account_id FK "NULL for interbank"
    varchar beneficiary_bank_code "interbank only"
    varchar beneficiary_account_no "interbank only"
    varchar beneficiary_name
    decimal amount
    decimal fee
    varchar currency
    varchar transfer_type
    varchar payment_reference UK
    varchar narration
    varchar status
    varchar failure_reason
    varchar session_id
    uuid source_transaction_id FK,UK
    uuid dest_transaction_id FK,UK
    timestamp created_at
    timestamp completed_at
  }

  AUDIT_LOGS {
    uuid log_id PK
    uuid staff_id FK "NULL = system"
    varchar action
    varchar entity_type
    uuid entity_id "polymorphic, no FK"
    jsonb old_values
    jsonb new_values
    inet ip_address
    timestamp created_at
  }
```

The 13 relationships, their cardinality and how each is enforced are listed in [the design document](ONI_OGOKRISTI_301931440_P1_Design.md#relationships-and-cardinality).
