# SSI Trading Analytics - Lakehouse Platform

Hệ thống Data Engineering phục vụ phân tích & báo cáo giao dịch Chứng khoán cơ sở, Phái sinh và
Chứng chỉ quỹ mở (OEF) của SSI Securities. Kiến trúc **Lakehouse** trên AWS S3 với Apache Iceberg.

> **Cài đặt lần đầu?** Xem **[`SETUP.md`](SETUP.md)**.

## Kiến trúc tổng quan

```text
SQL Server (4 DB)      Airbyte          s3://ssi-data/
┌─────────────┐       ┌──────┐          ┌──────────┐
│ Dimension    │ ────▶│ S3  │─────────▶│ raw/     │
│ tables       │      │ Raw │          ├──────────┤
└─────────────┘      └──────┘          │ bronze/  │ ◄── Spark (Iceberg)
HR API ─────────────▶──────┘           ├──────────┤
                                        │ silver/  │ ◄── Spark (Iceberg)
                                        ├──────────┤
                                        │ gold/    │ ◄── dbt + Trino (Iceberg)
                                        │  dim_*   │
                                        │  fact_*  │
                                        └──────────┘
                                             │ Spark Commission Engine
                                             ▼
                                        s3://ssi-report/
                                        ┌──────────────┐
                                        │ reporting/   │ ◄── Spark (Iceberg)
                                        │ fact_commission│
                                        │ 13 rpt_*     │
                                        └──────┬───────┘
                                               │ dbt views (SELECT *)
                                               ▼
                                             Trino
                                               │
                                               ▼
                                             BI / API
```

## Technology Stack

| Layer                  | Technology           | Storage                          |
| ---------------------- | -------------------- | -------------------------------- |
| Source OLTP            | SQL Server           | `Database/`                      |
| Ingestion              | Airbyte → S3 Parquet | `s3://ssi-data/raw/`             |
| Bronze (raw → Iceberg) | Spark                | `s3://ssi-data/bronze/`          |
| Silver (clean/dedup)   | Spark                | `s3://ssi-data/silver/`          |
| Gold (dim/fact)        | dbt + Trino          | `s3://ssi-data/gold/`            |
| **Commission Engine**  | **Spark**            | **`s3://ssi-report/reporting/`** |
| Reporting Views        | dbt (SELECT \*)      | Trino view                       |
| SQL Engine             | **Trino**            | Iceberg → S3                     |
| Data Quality           | Soda                 | -                                |

## Iceberg Time-Travel

Mỗi lần dbt rebuild dim/fact, Iceberg snapshot được tạo. Query dữ liệu tại thời điểm quá khứ:

```sql
SELECT * FROM ssi_data.gold.dim_customer
FOR VERSION AS OF TIMESTAMP '2027-03-15 10:00:00'
```

Query qua **Trino**.

## Cấu trúc thư mục

```
Database/                  Schema nguồn SQL Server
data-platform/
  spark/jobs/              PySpark: bronze_etl, silver_etl, commission_engine, generate_trades
  dbt/models/marts/        dim/, fact/, reports/ (views)
  dbt/snapshots/           SCD2 snapshot: snap_customer_profile
  trino/catalog/           ssi_data.properties + ssi_report.properties
  dagster/                 Jobs/Assets/Schedules (orchestration)
docker-compose.yml         Dagster + Spark (Master/Worker) + Trino + Hive Metastore + dbt + Superset
```

## Dagster Jobs (thay Airflow DAGs)

| #   | DAG                     | Vai trò                  | Ghi vào                          |
| --- | ----------------------- | ------------------------ | -------------------------------- |
| 0   | `generate_trades`       | Spark sinh giao dịch     | Silver Equity/Derivatives/OEF    |
| 1   | `ingest_raw`            | Airbyte → Raw Parquet    | `s3://ssi-data/raw/`             |
| 2   | `bronze_etl`            | Spark Bronze ETL         | `s3://ssi-data/bronze/`          |
| 3   | `bronze_soda`           | Soda quality             | -                                |
| 4   | `silver_etl`            | Spark Silver ETL         | `s3://ssi-data/silver/`          |
| 5   | `silver_soda`           | Soda quality             | -                                |
| 6   | `gold_dbt`              | dbt dim/fact             | `s3://ssi-data/gold/`            |
| 7   | `gold_quality`          | dbt test + Soda          | -                                |
| 8   | **`commission_engine`** | **Spark tính 13 report** | **`s3://ssi-report/reporting/`** |
| 9   | `reporting`             | dbt views (SELECT \*)    | Trino views                      |

## BI - Apache Superset

- UI: `http://localhost:8088` (user/pass `admin`)
- Datasource: Trino catalog `ssi_report` (13 view `reporting.rpt_*`) — scan trong **Databases** sau khi có dữ liệu từ pipeline.
- Sơ đồ 13 báo cáo→chart: README mục dưới.

## 13 Reports (tính bởi Spark Commission Engine)

Kết quả ghi vào `s3://ssi-report/reporting/` dưới dạng Iceberg tables.
dbt chỉ tạo view `SELECT *` để BI có thể query qua Trino.
