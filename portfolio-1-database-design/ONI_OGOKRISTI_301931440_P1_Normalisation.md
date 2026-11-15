# EgoTrust Transfer and Account Records — normalisation

The example uses the saved sample records. The full set of fields is in the design and schema.

## Starting grouped records

| customer_id | account records (list) |
| --- | --- |
| 101 | [201] |


The record IDs are grouped in a list. In 1NF, each record has its own row and each cell holds one value.

## 1NF: one value per cell

| account.account_id | account.customer_id | account.account_number | customer.customer_id | customer.customer_ref |
| --- | --- | --- | --- | --- |
| 201 | 101 | 1000000001 | 101 | CUS-001 |

Key: account_id.

## 2NF: depend on the whole key

The declared candidate keys do not introduce a partial dependency here, so the 1NF rows stay unchanged at this step.

## account_example

| account.account_id | account.customer_id | account.account_number | customer.customer_id | customer.customer_ref |
| --- | --- | --- | --- | --- |
| 201 | 101 | 1000000001 | 101 | CUS-001 |

## 3NF: store each entity’s details once

The entity keys determine their own descriptions. Related records keep foreign keys rather than repeating those descriptions.

## customer

| customer_id | customer_ref | full_name | kyc_status | created_on |
| --- | --- | --- | --- | --- |
| 101 | CUS-001 | Amina Example | verified | 2026-01-15 |

## account

| account_id | customer_id | account_number | account_type | currency_code | balance | opened_on |
| --- | --- | --- | --- | --- | --- | --- |
| 201 | 101 | 1000000001 | savings | NGN | 12500.5 | 2026-01-16 |

## transfer

| transfer_id | account_id | reference | amount | channel | rail | status | occurred_at |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 301 | 201 | TRF-001 | 2500 | mobile | NIP | failed | 2026-02-01T09:30:00+00:00 |

## Dependencies

- customer: (customer_id) → customer_ref, full_name, kyc_status, created_on
- account: (account_id) → customer_id, account_number, account_type, currency_code, balance, opened_on
- transfer: (transfer_id) → account_id, reference, amount, channel, rail, status, occurred_at

Joining the decomposed sample tables reproduces the original 1 example rows. The design assumes the declared keys describe the relevant business dependencies.
