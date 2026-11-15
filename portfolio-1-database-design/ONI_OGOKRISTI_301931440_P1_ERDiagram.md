# EgoTrust Transfer and Account Records — ER diagram

```mermaid
erDiagram
    direction LR
    customer {
        bigint customer_id PK
        text customer_ref UK
        text full_name
        text kyc_status
        date created_on
    }
    account {
        bigint account_id PK
        bigint customer_id FK
        text account_number UK
        text account_type
        text currency_code
        numeric balance
        date opened_on
    }
    transfer {
        bigint transfer_id PK
        bigint account_id FK
        text reference UK
        numeric amount
        text channel
        text rail
        text status
        timestamptz occurred_at
    }
    customer ||--o{ account : "customer_id"
    account ||--o{ transfer : "account_id"
```

PK identifies a record; FK links to another table; UK marks a single-field unique value. The relationship ends show exactly one, zero or one, or zero or many records. Composite unique keys and conditional rules are listed in the schema and design.

[Diagram image](../images/ONI_OGOKRISTI_301931440_ERDiagram.png)
