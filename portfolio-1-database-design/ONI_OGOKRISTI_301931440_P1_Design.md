# EgoTrust Transfer and Account Records — database design

My case study records customer, account, transfer.

## Users

- Retail and SME customers
- Bank staff and compliance officers
- System administrators and external payment systems

## Main operations

- Record account openings
- Record intrabank, NIP, and PAPSS transfers
- Review transfer activity and summarize account usage

## Entities

| Entity | Information stored |
| --- | --- |
| customer | Stores a synthetic customer reference and basic profile and KYC status for the exercise. |
| account | Stores one customer's account details and exercise balance. |
| transfer | Stores a transfer record associated with one account, including its channel, rail, status, and time. |

## customer

| Field | Type | Key | Required |
| --- | --- | --- | --- |
| customer_id | BIGINT | PK | Yes |
| customer_ref | TEXT | Unique | Yes |
| full_name | TEXT |  | Yes |
| kyc_status | TEXT |  | Yes |
| created_on | DATE |  | Yes |
- Unique key: (customer_ref).

## account

| Field | Type | Key | Required |
| --- | --- | --- | --- |
| account_id | BIGINT | PK | Yes |
| customer_id | BIGINT | FK | Yes |
| account_number | TEXT | Unique | Yes |
| account_type | TEXT |  | Yes |
| currency_code | TEXT |  | Yes |
| balance | NUMERIC(18,2) |  | Yes |
| opened_on | DATE |  | Yes |
- customer_id → customer.customer_id
- Unique key: (account_number).

## transfer

| Field | Type | Key | Required |
| --- | --- | --- | --- |
| transfer_id | BIGINT | PK | Yes |
| account_id | BIGINT | FK | Yes |
| reference | TEXT | Unique | Yes |
| amount | NUMERIC(18,2) |  | Yes |
| channel | TEXT |  | Yes |
| rail | TEXT |  | Yes |
| status | TEXT |  | Yes |
| occurred_at | TIMESTAMPTZ |  | Yes |
- account_id → account.account_id
- Unique key: (reference).

## Relationships and business rules

- Each synthetic customer reference identifies at most one customer.
- Every account must reference an existing customer through customer_id.
- Each modeled account number identifies at most one account.
- An account balance must be at least zero under the no-overdraft exercise assumption.
- Every transfer record must reference an existing account through account_id.
- A transfer reference can be recorded only once, supporting duplicate-submission protection.
- A recorded transfer amount must be greater than zero.

## Assumptions

- Use synthetic customer references, account numbers, and transfer references; do not store real personal or payment data.
- Each account belongs to exactly one customer, and each transfer record refers to one account. This simplified exercise does not model both sides of a transfer.
- Accounts do not permit overdrafts in this exercise, so their recorded balances must be nonnegative.
- Transfer amounts are positive, and each transfer reference is unique across the modeled records.
- Normalization example: Account has a customer_id foreign key. Keep customer_ref, full_name, and kyc_status in Customer and account-specific facts in Account, avoiding repeated customer details across accounts. With atomic fields and single-column keys, this illustrates separating customer attributes that depend on customer_id from account attributes; the example uses no repeated ancestor roles.

