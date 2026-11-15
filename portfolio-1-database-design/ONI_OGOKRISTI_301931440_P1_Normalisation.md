# EgoTrust — Normalisation

Ogokristi Oni · Student ID 301931440 · MIT 8103 Portfolio 1

## Overview

This document explains how the EgoTrust database schema satisfies the requirements of database normalisation from First Normal Form (1NF) through Boyce-Codd Normal Form (BCNF).

---

## First Normal Form (1NF)

**Rule:** Every column contains only atomic (indivisible) values, there are no repeating groups, and each row is uniquely identifiable.

**How the schema satisfies 1NF:**

- All columns store single, atomic values. For example, customer names are split into `first_name` and `last_name` rather than stored in a single `full_name` field.
- Phone numbers and BVN are stored as individual values, not as comma-separated lists.
- KYC documents are stored in a separate `kyc_documents` table with one row per document, rather than as multiple columns (`doc_1`, `doc_2`, etc.) in the `customers` table.
- Every table has a primary key (`customer_id`, `account_id`, `transaction_id`, etc.) ensuring each row is uniquely identifiable.

**Example — avoiding repeating groups:**

Instead of:

| customer_id | name  | doc_type_1   | doc_number_1    | doc_type_2   | doc_number_2 |
|-------------|-------|--------------|-----------------|--------------|--------------|
| 1           | Tunde | national_id  | NIN-1234567890  | utility_bill | UB-2024-0045 |

The schema uses a separate `kyc_documents` table:

| kyc_id | customer_id | document_type | document_number |
|--------|-------------|---------------|-----------------|
| 1      | 1           | national_id   | NIN-1234567890  |
| 2      | 1           | utility_bill  | UB-2024-0045   |

---

## Second Normal Form (2NF)

**Rule:** The table must be in 1NF, and every non-key attribute must depend on the entire primary key (no partial dependencies).

**How the schema satisfies 2NF:**

Since all tables use a single-column primary key (UUID), partial dependencies are structurally impossible — there is no composite key from which a column could depend on only part of it.

However, the design choice of separate tables also prevents what would have been 2NF violations in a denormalised design:

**Example — why `kyc_documents` is separate:**

If KYC data were stored in the `customers` table with a composite key of `(customer_id, document_type)`, columns like `first_name` and `email` would depend only on `customer_id`, not on the full composite key. This would violate 2NF. By placing KYC documents in their own table with `kyc_id` as the sole primary key and `customer_id` as a foreign key, the partial dependency is eliminated.

**Example — why `transactions` is separate from `accounts`:**

Transaction details (amount, narration, channel) depend on the `transaction_id`, not on the `account_id`. Storing transactions directly in the accounts table would create partial dependencies if a composite key were used.

---

## Third Normal Form (3NF)

**Rule:** The table must be in 2NF, and no non-key attribute should transitively depend on the primary key (i.e., non-key columns must not depend on other non-key columns).

**How the schema satisfies 3NF:**

- **Branches are in a separate table:** If branch details (`branch_name`, `branch_code`, `city`, `state`) were stored directly in the `accounts` table, they would transitively depend on `account_id` through `branch_id`. By normalising branch data into the `branches` table and referencing it via `branch_id` FK in `accounts`, this transitive dependency is removed.

- **Staff are in a separate table:** Similarly, staff details are not embedded in `audit_logs`. The `audit_logs` table references `staff_id` as a foreign key, and staff attributes like `first_name`, `last_name`, `role` live only in the `staff` table.

- **Customers are separate from accounts:** Customer attributes (`email`, `phone_number`, `bvn`) are not duplicated in the `accounts` table. The `accounts` table stores only the `customer_id` foreign key.

**Example — preventing transitive dependency:**

Without normalisation:

| account_id | account_number | branch_id | branch_name   | branch_code | city  |
|------------|----------------|-----------|---------------|-------------|-------|
| 1          | 0012345001     | BR-001    | Marina Branch | MRN001      | Lagos |

Here, `branch_name` and `city` depend on `branch_id`, not directly on `account_id`. This is a transitive dependency. The normalised design stores branch information only in the `branches` table.

---

## Boyce-Codd Normal Form (BCNF)

**Rule:** The table must be in 3NF, and for every functional dependency X → Y, X must be a superkey.

**How the schema satisfies BCNF:**

All functional dependencies in each table have the primary key (or a superkey) as their determinant:

| Table            | Functional Dependency                          | Determinant is Superkey? |
|------------------|------------------------------------------------|--------------------------|
| `customers`      | `customer_id → first_name, last_name, ...`     | Yes (`customer_id` is PK)|
| `customers`      | `bvn → customer_id` (unique constraint)        | Yes (`bvn` is a candidate key) |
| `customers`      | `email → customer_id` (unique constraint)       | Yes (`email` is a candidate key) |
| `accounts`       | `account_id → account_number, balance, ...`    | Yes (`account_id` is PK) |
| `accounts`       | `account_number → account_id` (unique)          | Yes (candidate key) |
| `transactions`   | `transaction_id → amount, channel, ...`        | Yes (`transaction_id` is PK) |
| `transactions`   | `reference → transaction_id` (unique)           | Yes (candidate key) |
| `transfers`      | `transfer_id → amount, status, ...`            | Yes (`transfer_id` is PK) |
| `kyc_documents`  | `kyc_id → customer_id, document_type, ...`     | Yes (`kyc_id` is PK) |
| `kyc_documents`  | `(customer_id, document_type) → kyc_id`         | Yes (candidate key via UNIQUE) |
| `transfers`      | `payment_reference → transfer_id` (unique)      | Yes (candidate key) |
| `transfers`      | `source_transaction_id → transfer_id` (unique)  | Yes (candidate key; NULLs allowed) |
| `branches`       | `branch_code → branch_id` (unique)              | Yes (candidate key) |

The `kyc_documents` table is notable: it has a composite unique constraint on `(customer_id, document_type)`, making it a candidate key. Both the PK (`kyc_id`) and this composite candidate key are superkeys, so all functional dependencies have a superkey as their determinant. BCNF is satisfied.

---

## Intentional Denormalisation

The `transactions` table stores `balance_before` and `balance_after` alongside each transaction. These values are derivable, which means the table is **deliberately not in strict 3NF**:

- `balance_after` is determined by the non-key attributes `(balance_before, transaction_type, amount)`: credits add, while debits and fees subtract. That is a transitive dependency `transaction_id → (balance_before, transaction_type, amount) → balance_after`.
- `balance_before` can be recomputed by replaying all earlier transactions for the account.

The same applies to `accounts.balance`, which equals the `balance_after` of the account's latest successful transaction.

This denormalisation is kept on purpose, for the following reasons:

1. **Performance:** Computing running balances across millions of transactions for every statement request would be computationally expensive.
2. **Audit trail:** Storing balance snapshots creates an immutable audit trail required by banking regulations — each transaction record is self-contained evidence.
3. **Consistency verification:** The `balance_after` of one transaction should equal the `balance_before` of the next, providing a built-in consistency check.

This is a common and accepted practice in financial systems where auditability and performance outweigh the storage cost of redundant data. The risk it introduces (an update anomaly where the stored balance drifts from the ledger) is controlled by updating the balance and inserting the ledger row in the **same database transaction** (Portfolio 3, A1), and can be audited with:

```sql
-- Any rows returned indicate a balance that disagrees with the ledger
SELECT a.account_number, a.balance, t.balance_after
FROM accounts a
JOIN LATERAL (
    SELECT balance_after FROM transactions
    WHERE account_id = a.account_id AND status = 'successful'
    ORDER BY created_at DESC, reference DESC LIMIT 1
) t ON TRUE
WHERE a.balance <> t.balance_after;
```

---

## Summary

| Normal Form | Status    | Key Design Decision |
|-------------|-----------|---------------------|
| 1NF         | Satisfied | Atomic values, no repeating groups, PKs on all tables |
| 2NF         | Satisfied | Single-column PKs eliminate partial dependencies |
| 3NF         | Satisfied, with one documented exception | Branch, staff, customer data in separate tables; derived balance columns in `transactions` and `accounts` are kept intentionally |
| BCNF        | Satisfied for all tables except that exception | All other determinants are superkeys (including candidate keys) |
