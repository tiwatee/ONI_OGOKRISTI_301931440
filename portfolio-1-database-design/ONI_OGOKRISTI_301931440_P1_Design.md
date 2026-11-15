# EgoTrust — Database Design

Ogokristi Oni · Student ID 301931440 · MIT 8103 Portfolio 1

## Case Study: EgoTrust — Digital Banking and Payments Platform

**Organisation Type:** Bank / Fintech Platform

EgoTrust is a digital banking platform providing core banking services: customer account management, fund transfers (intrabank and interbank via NIP/PAPSS), deposits, withdrawals, and real-time transaction logging for retail and SME customers.

### Users of the Database
- Retail and SME customers (account holders)
- Bank operations staff (tellers, relationship managers)
- Compliance and audit officers
- System administrators
- External payment switch integrations (NIP, PAPSS)

### Major Data Stored
- Customer profiles and KYC records
- Bank accounts (savings, current, domiciliary)
- Transaction ledger (credits, debits, reversals, fees)
- Interbank transfer records
- Staff records and audit trails
- Branch information

### Key Database Operations
- Account opening, KYC verification, freeze/unfreeze
- Fund transfers (intrabank and interbank)
- Transaction reversal and settlement
- Account statement generation
- Audit trail querying

---

## Entity-Relationship Design

The schema consists of **8 entities**:

1. **CUSTOMERS** — Core customer records with BVN and contact details (KYC status is derived from KYC_DOCUMENTS)
2. **ACCOUNTS** — Bank accounts (savings, current, domiciliary) linked to customers and branches
3. **TRANSACTIONS** — Immutable ledger entries recording every credit, debit, reversal, and fee
4. **TRANSFERS** — Fund movement records linking a source account to an internal destination account or an external beneficiary
5. **KYC_DOCUMENTS** — Identity verification documents per customer, with the verifying staff member
6. **BRANCHES** — Bank branch locations
7. **STAFF** — Bank employees with role-based classification
8. **AUDIT_LOGS** — Change tracking for compliance (stores old/new values as JSONB)

### Relationships and Cardinality

| # | Relationship | Cardinality | Optionality | Enforced by |
|---|---|---|---|---|
| R1 | Customer **owns** Account | 1 : N | An account must have exactly one owner; a customer may have zero or more accounts | `accounts.customer_id` FK, NOT NULL |
| R2 | Customer **submits** KYC Document | 1 : N | One document per type per customer | `kyc_documents.customer_id` FK + `UNIQUE(customer_id, document_type)` |
| R3 | Branch **hosts** Account | 1 : N | Every account is domiciled at one branch | `accounts.branch_id` FK, NOT NULL |
| R4 | Branch **employs** Staff | 1 : N | Every staff member belongs to one branch | `staff.branch_id` FK, NOT NULL |
| R5 | Staff **verifies** KYC Document | 1 : N | Optional while pending; required once verified | `kyc_documents.verified_by` FK + CHECK |
| R6 | Staff **performs** Audit Log action | 1 : N | Optional (NULL = automated system action) | `audit_logs.staff_id` FK, nullable |
| R7 | Account **records** Transaction | 1 : N | Every ledger entry belongs to one account | `transactions.account_id` FK, NOT NULL |
| R8 | Account **sends** Transfer (source) | 1 : N | Mandatory | `transfers.source_account_id` FK, NOT NULL |
| R9 | Account **receives** Transfer (destination) | 1 : N | Intrabank only; NULL for NIP/PAPSS, where beneficiary bank/account columns are used instead | `transfers.destination_account_id` FK + CHECK |
| R10 | Transfer **has debit leg** Transaction | 1 : 1 | Optional (absent while pending or if it failed) | `transfers.source_transaction_id` FK + UNIQUE |
| R11 | Transfer **has credit leg** Transaction | 1 : 1 | Intrabank only | `transfers.dest_transaction_id` FK + UNIQUE |
| R12 | Transaction **reverses** Transaction | 1 : 1 (recursive) | Required for, and only for, `reversal` entries | `transactions.reverses_transaction_id` self-FK + CHECK |
| R13 | Audit Log **refers to** any entity | N : 1 (polymorphic) | Mandatory | `entity_type` + `entity_id`, checked by the application (a single FK cannot point at several tables) |

R9, R10 and R11 are the subtle ones. An interbank transfer only has an EgoTrust account on the sending side, so the destination FK must be optional, and the beneficiary's bank code and account number are stored on the transfer instead. A CHECK constraint enforces the rule for each transfer type.

---

## Design Decisions

1. **UUID primary keys** — Preferred over auto-increment integers for distributed system compatibility (relevant for Portfolio 5's distributed database discussion) and to prevent enumeration attacks on account endpoints.

2. **CHECK constraints for status fields** — Enforced at the database level rather than application-only validation, ensuring data integrity even when accessed through different services (mobile API, web, branch systems).

3. **Separate transfers table** — Rather than inferring transfers from paired transactions, a dedicated `transfers` table captures the full lifecycle of a fund movement (pending → processing → successful/failed/reversed) along with metadata like fees, payment references, and failure reasons.

4. **JSONB for audit logs** — Using `old_values` and `new_values` as JSONB columns provides flexibility to audit any entity type without creating separate audit tables per entity.

5. **Business rules as CHECK constraints** — Beyond status lists, the schema enforces cross-column rules: verified KYC documents must name a verifier, failed transfers must give a reason, domiciliary accounts must hold foreign currency, and an account cannot transfer to itself.

6. **No duplicate indexes** — PostgreSQL already indexes every PRIMARY KEY and UNIQUE column, so only foreign keys and filter columns get explicit indexes.

7. **Intentional denormalisation in transactions** — `balance_before` and `balance_after` are stored with each transaction for auditability and performance (documented in [the normalisation analysis](ONI_OGOKRISTI_301931440_P1_Normalisation.md)).

---

---

## Tables at a Glance

| Table | Primary key | Foreign keys | Other keys / rules |
|---|---|---|---|
| `branches` | `branch_id` | — | `branch_code` unique; status list |
| `staff` | `staff_id` | `branch_id` | `email` unique; role list |
| `customers` | `customer_id` | — | `email`, `phone_number`, `bvn` unique; BVN must be 11 digits |
| `kyc_documents` | `kyc_id` | `customer_id`, `verified_by` | `(customer_id, document_type)` unique; verified ⇒ verifier and date required |
| `accounts` | `account_id` | `customer_id`, `branch_id` | `account_number` unique, 10 digits (NUBAN); `balance >= 0`; domiciliary ⇔ foreign currency |
| `transactions` | `transaction_id` | `account_id`, `reverses_transaction_id` (self) | `reference` unique; `amount > 0`; reversal ⇔ reverses another entry |
| `transfers` | `transfer_id` | `source_account_id`, `destination_account_id`, `source_transaction_id`, `dest_transaction_id` | `payment_reference` unique; no self-transfer; intrabank ⇒ internal destination, NIP/PAPSS ⇒ beneficiary details; failed ⇒ reason |
| `audit_logs` | `log_id` | `staff_id` | `entity_type` list; polymorphic `entity_id` (no FK, documented) |

Full column definitions are in [the schema](ONI_OGOKRISTI_301931440_P1_Schema.sql). Every rule above is tested by [the constraint tests](ONI_OGOKRISTI_301931440_P1_ConstraintTests.sql).

## Assumptions

- All names, BVNs, phone numbers and account numbers are fictional.
- Balances are held in the account's own currency; there is no currency conversion in this exercise.
- Accounts cannot be overdrawn.
- For interbank transfers (NIP, PAPSS) only the EgoTrust side of the movement is in our ledger; the receiving bank keeps its own records.
