# SSI Trading Analytics - Lakehouse Platform

Hệ thống Data Engineering phục vụ phân tích & báo cáo giao dịch Chứng khoán cơ sở, Phái sinh và
Chứng chỉ quỹ mở (OEF) của SSI Securities. Kiến trúc **Lakehouse** trên AWS S3 với Apache Iceberg,
**không sử dụng Spark** - toàn bộ transform thực hiện bằng **dbt** thông qua **Trino**.

> **Cài đặt lần đầu?** Xem **[`SETUP.md`](SETUP.md)**.

## Kiến trúc tổng quan

```text
SQL Server (4 DB)      Airbyte          s3://ssi-data/
┌─────────────┐       ┌──────┐          ┌──────────┐
│ Dimension    │ ────▶│ S3  │─────────▶│ raw/     │   ← Airbyte đẩy Parquet lên S3
│ tables       │      │ Raw │          ├──────────┤
└─────────────┘      └──────┘          │ bronze/  │   ← dbt (Iceberg)
HR API ─────────────▶───────┘          ├──────────┤
                                        │ silver/  │   ← dbt (Iceberg)
                                        ├──────────┤
                                        │ gold/    │   ← dbt (Iceberg)
                                        │  dim_*   │
                                        │  fact_*  │
                                        └────┬─────┘
                                             │ dbt (13 báo cáo)
                                             ▼
                                        s3://ssi-report/
                                        ┌──────────────┐
                                        │ reporting/   │   ← dbt (Iceberg)
                                        │ 13 rpt_*     │
                                        └──────┬───────┘
                                               │
                                               ▼
                                             Trino
                                               │
                                               ▼
                                         BI / API
```

## Technology Stack

| Layer                  | Technology                         | Storage                      |
| ---------------------- | ---------------------------------- | ---------------------------- |
| Source OLTP            | SQL Server (localhost)             | `Database/`                  |
| Ingestion              | Airbyte → S3 Parquet               | `s3://ssi-data/raw/`         |
| Bronze (raw → Iceberg) | **dbt + Trino**                    | `s3://ssi-data/bronze/`      |
| Silver (clean/dedup)   | **dbt + Trino**                    | `s3://ssi-data/silver/`      |
| Gold (dim/fact)        | dbt + Trino                        | `s3://ssi-data/gold/`        |
| Reporting (13 reports) | **dbt + Trino**                    | `s3://ssi-report/reporting/` |
| SQL Engine             | **Trino**                          | Iceberg → S3                 |
| Orchestration          | **Dagster** (Airbyte + dbt + Soda) | -                            |
| Data Quality           | Soda                               | -                            |
| BI                     | Apache Superset                    | Trino (`ssi_report`)         |

> ❌ **Đã loại bỏ Spark hoàn toàn** (bronze_etl.py, silver_etl.py, commission_engine.py). Thay thế
> bằng dbt models SQL trong `data-platform/dbt/models/staging/` + `data-platform/dbt/models/marts/reports/`.

## Luồng xử lý (Dagster)

```
Airbyte (5 connections) ──► s3://ssi-data/raw/
        ▼
dbt tag:bronze   ──► s3://ssi-data/bronze/   (26 tables)
        ▼
dbt tag:silver   ──► s3://ssi-data/silver/   (26 tables)
        ▼
dbt dimension/fact ─► s3://ssi-data/gold/    (dim_*, fact_*)
        ▼
dbt tag:report   ──► s3://ssi-report/reporting/  (13 rpt_*)
        ▼
Superset BI (Trino → ssi_report.reporting.*)
```

## Dagster Jobs

| Job             | Vai trò                            | Ghi vào                           |
| --------------- | ---------------------------------- | --------------------------------- |
| `ingest_raw`    | Airbyte → S3 raw Parquet           | `s3://ssi-data/raw/`              |
| `dbt_transform` | bronze → silver → gold → reporting | `ssi_data` + `ssi_report` trên S3 |
| `soda_quality`  | Soda quality checks                | -                                 |
| `main_pipeline` | Pipeline tổng hợp hằng ngày (3h)   | -                                 |

## Cấu trúc thư mục

```
Database/                        Schema nguồn SQL Server (4 DB) + seed data
data-platform/
  airbyte/                       Octavia config: sources MSSQL → destination S3
  dbt/models/
    staging/bronze/              dbt models: raw Parquet → Iceberg bronze (26)
    staging/silver/              dbt models: bronze → silver (26)
    marts/                       dim/, fact/, intermediate/, reports/ (13)
  trino/catalog/                 ssi_data, ssi_report, ssi_raw, mssql_* (verify)
  dagster/                       Assets/Jobs/Schedules (orchestration)
docker-compose.yml               Dagster + Trino + Hive Metastore + Superset + hr-api + dbt
```

## Iceberg Time-Travel

Mỗi lần dbt rebuild dim/fact, Iceberg snapshot tạo mới. Query tại thời điểm quá khứ:

```sql
SELECT * FROM ssi_data.gold.dim_customer
FOR VERSION AS OF TIMESTAMP '2027-03-15 10:00:00'
```

Query qua **Trino** (`docker exec project_de-trino-1 trino`).

## BI - Apache Superset

- UI: `http://localhost:8088` (user/pass `admin`)
- Datasource: Trino catalog `ssi_report` (13 view `reporting.rpt_*`)

## 13 Reports

Được tính trực tiếp bằng **dbt** từ gold dim/fact (không còn Spark Commission Engine).
Xem `data-platform/dbt/models/marts/reports/`.
