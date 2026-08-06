# Data Platform Architecture (Lakehouse)

## Overall Flow

```text
Source Systems
        │
        ▼
Airbyte / Debezium / Python
        │
        ▼
S3 Raw (Parquet)
        │
        ▼
Airflow Orchestration
        │
        ▼
Spark Bronze ETL (PySpark)
        │
        ▼
Bronze Iceberg (S3)
        │
        ▼
Soda Quality Check
        │
        ▼
Spark Silver ETL (PySpark)
        │
        ▼
Silver Iceberg (S3)
        │
        ▼
Soda Quality Check
        │
        ▼
dbt + Trino
        │
        ▼
Gold Iceberg (S3)
        │
        ▼
dbt Test + Soda
        │
        ├───────────────────────────────┐
        ▼                               ▼
Business Processing              Reporting / BI
(Spark/Python)                   (dbt)
        │                               │
        ▼                               ▼
Business Fact Tables            Reporting Tables
        └───────────────┬───────────────┘
                        ▼
                    Trino
                        │
                        ▼
                 BI / API / Analytics
```

---

## Step 1. Ingestion

**Technology**

- Airbyte
- Debezium
- Python (custom connectors)

**Responsibilities**

- Extract data from source systems.
- Load data into Amazon S3.
- No transformation.
- Preserve original data.

**Output**

- Raw Zone (Parquet/JSON)

---

## Step 2. Bronze Layer

**Technology**

- Airflow
- Spark (PySpark)
- Apache Iceberg

**Responsibilities**

- Validate schema
- Cast data types
- Add ETL metadata
- Handle CDC merge
- Partition data
- Write Iceberg tables

**Business Logic**

- Not allowed

**Output**

- Bronze Iceberg Tables

---

## Step 3. Bronze Data Quality

**Technology**

- Soda

**Responsibilities**

- Schema validation
- Null check
- Duplicate check
- Freshness
- Row count validation

---

## Step 4. Silver Layer

**Technology**

- Spark (PySpark)

**Responsibilities**

- Cleaning
- Deduplication
- Standardization
- Join multiple datasets
- Data enrichment
- Basic business rules

**Output**

- Silver Iceberg Tables

---

## Step 5. Silver Data Quality

**Technology**

- Soda

**Responsibilities**

- Foreign key validation
- Missing data check
- Distribution check
- Business validation

---

## Step 6. Gold Layer

**Technology**

- dbt
- Trino

**Responsibilities**

- Fact tables
- Dimension tables
- Star schema
- Data marts
- Semantic layer
- Simple SQL calculations

**Implementation**

- dbt connects to Trino (Iceberg catalog)
- Reads Silver Iceberg tables, writes Gold Iceberg tables

**Output**

- Gold Iceberg Tables

---

## Step 7. Gold Data Quality

**Technology**

- dbt Test
- Soda

**Responsibilities**

- Unique constraints
- Relationship validation
- Accepted values
- Business validation

---

## Step 8. Business Processing

**Technology**

- Spark (PySpark)

**Responsibilities**

- Complex business rules
- Rule engine
- KPI calculation
- Ranking
- Scoring
- Multi-step calculations

**Implementation**

- Python code (commission_engine.py)

**Output**

- Business Fact Tables (Iceberg)

---

## Step 9. Reporting Layer

**Technology**

- dbt

**Responsibilities**

- Reporting models
- Summary tables
- Dashboard models
- BI views

**Output**

- Reporting Tables

---

## Step 10. Query Layer

**Technology**

- Trino

**Responsibilities**

- SQL query engine
- BI access
- API access

---

# Technology Stack

| Layer          | Technology             |
| -------------- | ---------------------- |
| Storage        | Amazon S3              |
| Table Format   | Apache Iceberg         |
| Ingestion      | Airbyte                |
| Orchestration  | Apache Airflow         |
| ETL Processing | Apache Spark (PySpark) |
| Modeling       | dbt                    |
| SQL Engine     | Trino                  |
| Data Quality   | Soda                   |
| BI             | Power BI               |

# Design Principles

1.  Store all data in Amazon S3 using Iceberg tables.
2.  Airflow orchestrates only; it never processes data.
3.  Spark handles ETL and complex business processing.
4.  dbt is responsible for data modeling and reporting.
5.  Trino provides SQL access to Iceberg tables.
6.  Soda validates data quality after each processing layer.
7.  Keep business logic separate from data modeling.
8.  All intermediate and final datasets are stored as Iceberg tables.
