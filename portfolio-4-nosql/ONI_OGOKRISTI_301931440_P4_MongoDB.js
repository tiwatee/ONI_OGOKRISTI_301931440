// ============================================================
// EgoTrust — NoSQL Data Modelling with MongoDB
// MIT 8103 Advanced Database Systems — Portfolio 4
// Ogokristi Oni · Student ID 301931440
// ============================================================
// Run with mongosh (MongoDB 6.0+):
//   mongosh egotrust_nosql ONI_OGOKRISTI_301931440_P4_MongoDB.js
//
// The data mirrors the PostgreSQL seed data from Portfolio 1:
// same customers, same account numbers, same balances, and the
// PostgreSQL UUIDs are reused as MongoDB _id values. In a polyglot
// design, PostgreSQL stays the system of record and MongoDB holds
// read-optimised copies, so the IDs must match for the two stores
// to be reconciled.
//
// Money is stored as Decimal128 (NumberDecimal), never as a JS
// number/double: binary floating point cannot represent values
// like 0.10 exactly, which is unacceptable for balances.
// ============================================================

// Start from a clean database so the script can be re-run
db.dropDatabase();


// ============================================================
// PART A: Document Model Design
// ============================================================

// ------------------------------------------------------------
// A1: Customer Profile — Embedded Document Pattern
// One document holds the customer, their KYC documents, an
// account summary and app preferences. Loading a profile in the
// mobile app becomes a single read instead of three PostgreSQL
// JOINs (customers + kyc_documents + accounts).
//
// Embedding rule applied: KYC documents and accounts are bounded
// (a handful per customer), always read with the customer and
// rarely queried on their own, so they are embedded. Transactions
// are unbounded, so they are NOT embedded (see A2).
// ------------------------------------------------------------

db.customers.insertMany([
  {
    _id: "c3d4e5f6-0001-4000-8000-000000000001",
    firstName: "Tunde",
    lastName: "Adeyemi",
    email: "tunde.adeyemi@email.com",
    phone: "08012345678",
    bvn: "22345678901",
    dateOfBirth: ISODate("1990-05-15"),
    customerType: "retail",
    address: { street: "45 Lekki Phase 1", city: "Lagos", state: "Lagos", country: "Nigeria" },
    kyc: {
      status: "verified",
      tier: 3,
      documents: [
        { type: "national_id",  number: "NIN-1234567890", status: "verified",
          verifiedAt: ISODate("2026-10-01T10:00:00Z"), verifiedBy: "Kemi Adebayo" },
        { type: "utility_bill", number: "UB-2024-0045",   status: "verified",
          verifiedAt: ISODate("2026-10-01T10:05:00Z"), verifiedBy: "Kemi Adebayo" }
      ]
    },
    // Summary copy of the accounts. The authoritative balance is in PostgreSQL;
    // this copy is refreshed by an event (e.g. a Kafka consumer) after each posting.
    accounts: [
      { accountId: "d4e5f6a7-0001-4000-8000-000000000001", accountNumber: "0012345001",
        type: "savings", currency: "NGN", balance: NumberDecimal("249950.00"), status: "active" },
      { accountId: "d4e5f6a7-0001-4000-8000-000000000002", accountNumber: "0012345002",
        type: "current", currency: "NGN", balance: NumberDecimal("1500000.00"), status: "active" },
      { accountId: "d4e5f6a7-0001-4000-8000-000000000005", accountNumber: "0012345003",
        type: "domiciliary", currency: "USD", balance: NumberDecimal("3200.00"), status: "active" }
    ],
    preferences: {
      notifications: { email: true, sms: true, push: true },
      defaultAccount: "0012345001",
      language: "en",
      twoFactorEnabled: true
    },
    createdAt: ISODate("2026-10-01T09:00:00Z"),
    updatedAt: ISODate("2026-11-01T23:00:00Z")
  },
  {
    _id: "c3d4e5f6-0001-4000-8000-000000000002",
    firstName: "Ngozi",
    lastName: "Eze",
    email: "ngozi.eze@email.com",
    phone: "08098765432",
    bvn: "22345678902",
    dateOfBirth: ISODate("1985-11-20"),
    customerType: "retail",
    address: { street: "10 GRA", city: "Port Harcourt", state: "Rivers", country: "Nigeria" },
    kyc: {
      status: "verified",
      tier: 3,
      documents: [
        { type: "passport", number: "A09876543", status: "verified",
          verifiedAt: ISODate("2026-10-03T12:00:00Z"), verifiedBy: "Kemi Adebayo" }
      ]
    },
    accounts: [
      { accountId: "d4e5f6a7-0001-4000-8000-000000000003", accountNumber: "0023456001",
        type: "savings", currency: "NGN", balance: NumberDecimal("850000.00"), status: "active" }
    ],
    preferences: {
      notifications: { email: true, sms: false, push: true },
      defaultAccount: "0023456001",
      language: "en",
      twoFactorEnabled: false
    },
    createdAt: ISODate("2026-10-03T11:30:00Z"),
    updatedAt: ISODate("2026-11-01T10:15:00Z")
  },
  {
    _id: "c3d4e5f6-0001-4000-8000-000000000003",
    firstName: "Fashola",
    lastName: "Enterprises",
    email: "info@fasholaent.com",
    phone: "08055551234",
    bvn: "22345678903",
    dateOfBirth: ISODate("1975-01-01"),
    customerType: "sme",
    address: { street: "22 Broad Street", city: "Lagos", state: "Lagos", country: "Nigeria" },
    kyc: {
      status: "pending",
      tier: 1,
      documents: [
        { type: "national_id", number: "NIN-9876543210", status: "pending",
          verifiedAt: null, verifiedBy: null }
      ]
    },
    accounts: [
      { accountId: "d4e5f6a7-0001-4000-8000-000000000004", accountNumber: "0034567001",
        type: "current", currency: "NGN", balance: NumberDecimal("5199950.00"), status: "active" }
    ],
    // Flexible schema: business customers carry extra fields that retail
    // customers do not have, without NULL columns or a separate table.
    business: {
      rcNumber: "RC-1234567",
      directors: ["Babatunde Fashola", "Aduke Fashola"],
      industry: "Wholesale trade"
    },
    preferences: {
      notifications: { email: true, sms: true, push: false },
      defaultAccount: "0034567001",
      language: "en",
      twoFactorEnabled: true
    },
    createdAt: ISODate("2026-10-10T14:00:00Z"),
    updatedAt: ISODate("2026-11-01T13:40:00Z")
  }
]);


// ------------------------------------------------------------
// A2: Transaction History — Bucket Pattern
// One document per account per day, holding that day's
// transactions plus a pre-computed summary. This keeps document
// count low, keeps each document well under the 16 MB limit, and
// matches how statements are read (by day / date range).
// ------------------------------------------------------------

db.transaction_buckets.insertMany([
  {
    _id: "d4e5f6a7-0001-4000-8000-000000000001_2026-11-01",
    accountId: "d4e5f6a7-0001-4000-8000-000000000001",
    accountNumber: "0012345001",
    date: ISODate("2026-11-01"),
    transactionCount: 2,
    transactions: [
      { reference: "TXN-20261101-001", type: "credit", amount: NumberDecimal("50000.00"),
        balanceAfter: NumberDecimal("250000.00"), channel: "api",
        narration: "Salary credit Nov 2026", status: "successful",
        timestamp: ISODate("2026-11-01T08:30:00Z") },
      { reference: "TXN-20261101-006", type: "fee", amount: NumberDecimal("50.00"),
        balanceAfter: NumberDecimal("249950.00"), channel: "api",
        narration: "SMS notification fee", status: "successful",
        timestamp: ISODate("2026-11-01T23:00:00Z") }
    ],
    dailySummary: {
      openingBalance: NumberDecimal("200000.00"),
      totalCredits:   NumberDecimal("50000.00"),
      totalDebits:    NumberDecimal("50.00"),
      closingBalance: NumberDecimal("249950.00")
    }
  },
  {
    _id: "d4e5f6a7-0001-4000-8000-000000000002_2026-11-01",
    accountId: "d4e5f6a7-0001-4000-8000-000000000002",
    accountNumber: "0012345002",
    date: ISODate("2026-11-01"),
    transactionCount: 1,
    transactions: [
      { reference: "TXN-20261101-002", type: "debit", amount: NumberDecimal("25000.00"),
        balanceAfter: NumberDecimal("1500000.00"), channel: "web",
        narration: "Transfer to Ngozi Eze", status: "successful",
        timestamp: ISODate("2026-11-01T10:15:00Z") }
    ],
    dailySummary: {
      openingBalance: NumberDecimal("1525000.00"),
      totalCredits:   NumberDecimal("0.00"),
      totalDebits:    NumberDecimal("25000.00"),
      closingBalance: NumberDecimal("1500000.00")
    }
  },
  {
    _id: "d4e5f6a7-0001-4000-8000-000000000004_2026-11-01",
    accountId: "d4e5f6a7-0001-4000-8000-000000000004",
    accountNumber: "0034567001",
    date: ISODate("2026-11-01"),
    transactionCount: 2,
    transactions: [
      { reference: "TXN-20261101-004", type: "debit", amount: NumberDecimal("100000.00"),
        balanceAfter: NumberDecimal("5200000.00"), channel: "branch",
        narration: "Vendor payment via NIP", status: "successful",
        timestamp: ISODate("2026-11-01T13:40:00Z") },
      { reference: "TXN-20261101-005", type: "fee", amount: NumberDecimal("50.00"),
        balanceAfter: NumberDecimal("5199950.00"), channel: "branch",
        narration: "NIP transfer fee", status: "successful",
        timestamp: ISODate("2026-11-01T13:40:00Z") }
    ],
    dailySummary: {
      openingBalance: NumberDecimal("5300000.00"),
      totalCredits:   NumberDecimal("0.00"),
      totalDebits:    NumberDecimal("100050.00"),
      closingBalance: NumberDecimal("5199950.00")
    }
  }
]);

// Appending a new transaction to today's bucket is one atomic upsert:
// MongoDB guarantees atomicity for all changes to a single document.
db.transaction_buckets.updateOne(
  { _id: "d4e5f6a7-0001-4000-8000-000000000001_2026-11-02",
    accountId: "d4e5f6a7-0001-4000-8000-000000000001" },
  {
    $setOnInsert: { accountNumber: "0012345001", date: ISODate("2026-11-02"),
                    "dailySummary.openingBalance": NumberDecimal("249950.00") },
    $push: { transactions: {
      reference: "TXN-20261102-101", type: "debit", amount: NumberDecimal("15000.00"),
      balanceAfter: NumberDecimal("234950.00"), channel: "pos",
      narration: "POS purchase", status: "successful",
      timestamp: ISODate("2026-11-02T16:45:00Z") } },
    $inc: { transactionCount: 1,
            "dailySummary.totalDebits": NumberDecimal("15000.00") },
    $set: { "dailySummary.closingBalance": NumberDecimal("234950.00") }
  },
  { upsert: true }
);


// ============================================================
// PART B: Key-Value Pattern — Session Store
// ============================================================
// Each session is looked up by a single key (the session ID) and
// expires automatically through a TTL index. Expiry times are
// relative to "now" so the sample sessions are still alive when
// the queries in Part C run (a TTL index would otherwise delete
// past-dated sessions within about a minute).

const now = new Date();
const hours = (h) => new Date(now.getTime() + h * 3600 * 1000);

db.sessions.insertMany([
  {
    _id: "sess_7f3a9c1e",
    customerId: "c3d4e5f6-0001-4000-8000-000000000001",
    device: { type: "mobile", os: "iOS 18", appVersion: "2.4.1" },
    ipAddress: "102.89.45.123",
    loginAt: now,
    expiresAt: hours(12),
    isActive: true
  },
  {
    _id: "sess_b81d44a0",
    customerId: "c3d4e5f6-0001-4000-8000-000000000002",
    device: { type: "web", browser: "Chrome", os: "Windows 11" },
    ipAddress: "105.112.78.45",
    loginAt: now,
    expiresAt: hours(12),
    isActive: true
  }
]);

// TTL index: MongoDB's background task removes each document once
// expiresAt has passed (it runs about every 60 seconds).
db.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });
db.sessions.createIndex({ customerId: 1, isActive: 1 });


// ============================================================
// PART C: Queries
// ============================================================

// C1: Key lookup — whole profile in one read (replaces 3 JOINs)
printjson(db.customers.findOne({ _id: "c3d4e5f6-0001-4000-8000-000000000001" }));

// C2: Query an embedded field — customers with pending KYC
printjson(db.customers.find(
  { "kyc.status": "pending" },
  { firstName: 1, lastName: 1, "kyc.status": 1, "kyc.tier": 1 }
).toArray());

// C3: Query inside an array — who owns NUBAN 0023456001?
printjson(db.customers.find(
  { "accounts.accountNumber": "0023456001" },
  { firstName: 1, lastName: 1, "accounts.$": 1 }
).toArray());

// C4: Statement for a date range (half-open, like the SQL version)
printjson(db.transaction_buckets.find(
  { accountId: "d4e5f6a7-0001-4000-8000-000000000001",
    date: { $gte: ISODate("2026-11-01"), $lt: ISODate("2026-12-01") } }
).sort({ date: 1 }).toArray());

// C5: Aggregation pipeline — debits/fees per channel across all accounts
printjson(db.transaction_buckets.aggregate([
  { $unwind: "$transactions" },
  { $match: { "transactions.type": { $in: ["debit", "fee"] },
              "transactions.status": "successful" } },
  { $group: {
      _id: "$transactions.channel",
      totalOut: { $sum: "$transactions.amount" },
      count: { $sum: 1 } } },
  { $sort: { totalOut: -1 } }
]).toArray());

// C6: Aggregation with $lookup — join sessions to customer names
printjson(db.sessions.aggregate([
  { $match: { isActive: true } },
  { $lookup: { from: "customers", localField: "customerId",
               foreignField: "_id", as: "customer" } },
  { $unwind: "$customer" },
  { $project: { _id: 1, "device.type": 1, expiresAt: 1,
                name: { $concat: ["$customer.firstName", " ", "$customer.lastName"] } } }
]).toArray());

// C7: Update an element of an embedded array with the positional operator
// — compliance verifies Fashola Enterprises' national ID
db.customers.updateOne(
  { _id: "c3d4e5f6-0001-4000-8000-000000000003", "kyc.documents.type": "national_id" },
  { $set: {
      "kyc.documents.$.status": "verified",
      "kyc.documents.$.verifiedAt": new Date(),
      "kyc.documents.$.verifiedBy": "Kemi Adebayo",
      "kyc.status": "verified",
      "kyc.tier": 2,
      updatedAt: new Date() } }
);


// ============================================================
// PART D: Indexes
// ============================================================

// Unique BVN — the same rule as the PostgreSQL UNIQUE constraint
db.customers.createIndex({ bvn: 1 }, { unique: true });

// Multikey index on an array field: supports C3 (lookup by NUBAN)
db.customers.createIndex({ "accounts.accountNumber": 1 }, { unique: true });

// KYC compliance queries (C2)
db.customers.createIndex({ "kyc.status": 1 });

// Statement range queries (C4): equality field first, then range field
db.transaction_buckets.createIndex({ accountId: 1, date: 1 });

// Full-text search on narrations
db.transaction_buckets.createIndex({ "transactions.narration": "text" });

// Proof that C4 uses the index: look for IXSCAN in the winning plan
printjson(db.transaction_buckets.find(
  { accountId: "d4e5f6a7-0001-4000-8000-000000000001",
    date: { $gte: ISODate("2026-11-01"), $lt: ISODate("2026-12-01") } }
).explain("executionStats").queryPlanner.winningPlan);

// Text search example
printjson(db.transaction_buckets.find({ $text: { $search: "salary" } }, { accountNumber: 1, date: 1 }).toArray());


// ============================================================
// PART E: Schema Validation
// ============================================================
// MongoDB is schema-flexible, not schema-less: a $jsonSchema
// validator enforces structure where integrity matters. The rules
// below mirror the PostgreSQL CHECK constraints on `transfers`.

db.createCollection("transfers", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["sourceAccountId", "amount", "currency", "transferType", "status", "createdAt"],
      properties: {
        sourceAccountId:      { bsonType: "string" },
        destinationAccountId: { bsonType: ["string", "null"],
                                description: "EgoTrust account; null for interbank" },
        beneficiaryBankCode:  { bsonType: ["string", "null"] },
        amount:   { bsonType: "decimal", description: "Decimal128 amount, must be > 0" },
        fee:      { bsonType: "decimal" },
        currency: { enum: ["NGN", "USD", "GBP", "EUR"] },
        transferType: { enum: ["intrabank", "nip", "papss"] },
        status:   { enum: ["pending", "processing", "successful", "failed", "reversed"] },
        createdAt: { bsonType: "date" }
      }
    },
    // $jsonSchema cannot compare a Decimal128 to a number, so the
    // "amount > 0" rule is added with a query-operator expression.
    amount: { $gt: NumberDecimal("0") }
  },
  validationAction: "error"
});

// Valid document — accepted
db.transfers.insertOne({
  sourceAccountId: "d4e5f6a7-0001-4000-8000-000000000002",
  destinationAccountId: "d4e5f6a7-0001-4000-8000-000000000003",
  amount: NumberDecimal("25000.00"),
  fee: NumberDecimal("0.00"),
  currency: "NGN",
  transferType: "intrabank",
  status: "successful",
  createdAt: ISODate("2026-11-01T10:15:00Z")
});

// Invalid document — rejected (unsupported currency, negative amount)
try {
  db.transfers.insertOne({
    sourceAccountId: "d4e5f6a7-0001-4000-8000-000000000002",
    amount: NumberDecimal("-500.00"),
    currency: "JPY",
    transferType: "nip",
    status: "pending",
    createdAt: new Date()
  });
} catch (e) {
  print("Validation rejected the document as expected: " + e.message);
}

print("EgoTrust NoSQL model loaded: " +
      db.customers.countDocuments() + " customers, " +
      db.transaction_buckets.countDocuments() + " transaction buckets, " +
      db.sessions.countDocuments() + " sessions, " +
      db.transfers.countDocuments() + " transfers.");
