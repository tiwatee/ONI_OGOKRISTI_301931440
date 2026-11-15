# Portfolio 4 — NoSQL and Advanced Data Models

## EgoTrust — Digital Banking & Payments Platform

**Student:** Ogokristi Oni · Student ID 301931440  
**Module:** MIT 8103 — Advanced Database Systems  
**Institution:** Miva Open University  

---

## Overview

This portfolio explores NoSQL data modelling using MongoDB alongside the existing PostgreSQL relational database. In a real-world fintech platform like EgoTrust, a polyglot persistence strategy uses the right database engine for each workload — PostgreSQL for transactional integrity, MongoDB for flexible document storage and high-throughput reads.

## File

| File | Description |
|------|-------------|
| `ONI_OGOKRISTI_301931440_P4_MongoDB.js` | mongosh script: document models, sample data, queries, indexes, and schema validation |

The MongoDB data **mirrors the PostgreSQL seed data**: the same three customers (Tunde Adeyemi, Ngozi Eze, Fashola Enterprises), the same account numbers and balances, and the PostgreSQL UUIDs reused as `_id` values. PostgreSQL remains the system of record, and MongoDB holds read-optimised copies that are kept in sync by events, so the IDs must match for the two stores to be reconciled.

## Data Models Implemented

### 1. Document Model — Customer Profiles (Embedded Pattern)

The customer document embeds KYC documents, account references, and user preferences into a single document. This eliminates the need for JOINs when loading a customer profile — a single read retrieves everything the mobile app or web dashboard needs.

```
Customer {
  _id, firstName, lastName, email, phone, bvn,
  address: { street, city, state, country },
  kyc: {
    status, tier,
    documents: [ { type, number, verifiedAt, verifiedBy } ]
  },
  accounts: [ { accountId, accountNumber, type, currency, balance (Decimal128), status } ],
  business: { rcNumber, directors[], industry },   // SME customers only
  preferences: { notifications, defaultAccount, language }
}
```

**Why embedding works here:** KYC documents and account summaries are always read with the customer, are bounded in size (a customer has only a few of each), and are rarely queried on their own. This fits MongoDB's embedding guidelines. Transactions are **not** embedded because they grow without limit and would eventually hit the 16 MB document cap.

**Flexible schema:** the SME customer carries a `business` sub-document (RC number, directors) that retail customers lack. A relational design would need either NULL-heavy columns or a separate table for this.

### 2. Bucket Pattern — Transaction History (`transaction_buckets`)

Transactions are grouped by account and day into "bucket" documents, with `_id` set to `<accountId>_<date>`. Instead of one document per transaction, each bucket holds a day's transactions and a pre-computed daily summary (opening balance, credits, debits, closing balance). New transactions are appended with a single atomic upsert (`$push` + `$inc`), which relies on MongoDB's guarantee that all changes to one document are atomic.

**Benefits:**
- Reduces document count by 10-100× compared to one-per-transaction
- Daily summary fields enable fast reporting without aggregation
- Date-range queries scan fewer documents
- Aligns with how statements are typically viewed (per-day)

### 3. Key-Value Pattern — Session Management

Sessions are looked up by a single key (the session ID) and carry a TTL (time-to-live) index that removes them automatically once `expiresAt` passes. The sample sessions expire 12 hours after the script runs, so they still exist when the queries execute. Redis is the more common choice for this in production; a MongoDB TTL collection serves the same purpose with richer querying (see the `$lookup` in C6).

## SQL vs MongoDB Comparison

| Operation | PostgreSQL (Portfolio 1-3) | MongoDB (Portfolio 4) |
|-----------|---------------------------|----------------------|
| Customer profile load | 3 JOINs (customers + kyc_documents + accounts) | Single document read |
| Transaction history | Index scan + WHERE filter | Bucket document lookup by date |
| Session lookup | Not modelled (typically Redis) | Key-value with TTL auto-expiry |
| KYC status check | JOIN + HAVING | Dot-notation query on embedded field |
| Data integrity | ACID transactions, FK constraints | Schema validation, application-level |
| Aggregation | GROUP BY, window functions | Aggregation pipeline ($match, $group, $unwind) |

## When to Use Each Engine

| Workload | Recommended Engine | Reason |
|----------|-------------------|--------|
| Fund transfers | PostgreSQL | ACID transactions, referential integrity |
| Account balances | PostgreSQL | Strong consistency, CHECK constraints |
| Customer profiles (read-heavy) | MongoDB | Embedded documents, fast single reads |
| Transaction analytics | MongoDB | Aggregation pipeline, bucket pattern |
| Session management | MongoDB | TTL indexes, key-value access pattern |
| Audit logs | PostgreSQL (JSONB) | Must be written in the same ACID transaction as the change it records |
| Real-time notifications | MongoDB | Flexible schema, capped collections |

## MongoDB Features Demonstrated

1. **Embedded documents**: nested objects and arrays within a single document
2. **Bucket pattern**: per-account, per-day buckets with atomic upsert appends
3. **Key-value pattern with TTL indexes**: automatic session expiry
4. **Aggregation pipeline**: `$unwind` → `$match` → `$group` → `$sort`, plus a `$lookup` join
5. **Schema validation**: `$jsonSchema` mirroring the PostgreSQL CHECK constraints, with one valid insert accepted and one invalid insert rejected
6. **Dot-notation and positional queries**: `kyc.status`, `accounts.accountNumber`, and `kyc.documents.$`
7. **Compound, multikey, unique and text indexes**, with `explain()` output showing an IXSCAN
8. **Decimal128 for money**: `NumberDecimal("249950.00")`. Doubles cannot represent amounts like 0.10 exactly, so they are never used for balances

## How to Run

```bash
# MongoDB 6.0+ with mongosh. The script drops and recreates egotrust_nosql,
# so it can be re-run safely.
mongosh egotrust_nosql ONI_OGOKRISTI_301931440_P4_MongoDB.js
```

The script prints each query result and ends with a summary line (`3 customers, 4 transaction buckets, 2 sessions, 1 transfers`) and the message "Validation rejected the document as expected".

**Evidence:** run the script and save a screenshot of its output as `screenshots/ONI_OGOKRISTI_301931440_P4_MongoDBOutput.png`. A free MongoDB Atlas M0 cluster also works if you don't want to install MongoDB locally: `mongosh "<atlas-connection-string>/egotrust_nosql" ONI_OGOKRISTI_301931440_P4_MongoDB.js`.

## Design Decisions

- **Polyglot persistence** — PostgreSQL remains the system of record for financial data (balances, transfers) where ACID compliance is non-negotiable. MongoDB handles read-heavy, schema-flexible workloads
- **Embedded vs referenced** — KYC documents are embedded (bounded, always co-accessed); transaction logs use the bucket pattern (unbounded data, time-series access)
- **Schema validation**: the `transfers` collection shows that MongoDB can enforce structure where integrity matters. MongoDB is schema-*flexible*, not schema-*less*.
- **Consistency between stores**: MongoDB copies are eventually consistent with PostgreSQL. A balance shown in the app may briefly lag a posting, so any decision that moves money re-reads the balance from PostgreSQL (see Portfolio 5, CAP analysis).

## References

- [MongoDB — Data Modeling](https://www.mongodb.com/docs/manual/data-modeling/)
- [MongoDB — Schema Validation](https://www.mongodb.com/docs/manual/core/schema-validation/)
- [MongoDB — TTL Indexes](https://www.mongodb.com/docs/manual/core/index-ttl/)
- [MongoDB — Model Monetary Data (Decimal128)](https://www.mongodb.com/docs/manual/tutorial/model-monetary-data/)
