# Hướng dẫn cài đặt Lakehouse Platform (Dagster + Superset)

## 0. Yêu cầu trước khi bắt đầu

- Docker + Docker Compose
- SQL Server instance
- AWS S3 buckets: `ssi-data` và `ssi-report`
- Airbyte (`abctl local install`)
- `sqlcmd` hoặc SSMS

## Bước 1: Tạo file `.env`

```bash
cp .env.example .env
```

Điền: `AWS_*`, `DAGSTER_POSTGRES_PASSWORD`, `CONN_*` (UUID connection từ Airbyte UI), `TRINO_*`, `MSSQL_HOST`.

## Bước 2: Khởi tạo SQL Server

```bash
docker compose --profile sqlserver up -d sqlserver
# Chạy Database/ scripts
```

## Bước 3: Cài Airbyte + tạo connection trên UI

```bash
abctl local install
```

Tạo: Sources (MSSQL ×4 + HR API) → Destination S3 (`ssi-data/raw/{source}/{table}/{date}/`)

Ghi UUID của 5 connections vào `.env`: `CONN_MSSQL_COMMON`, `CONN_MSSQL_EQUITY`, `CONN_MSSQL_DERIVATIVES`, `CONN_MSSQL_OEF`, `CONN_HR_API`.

## Bước 4: Khởi chạy Docker Compose

```bash
docker compose up -d hr-api hive-metastore-db hive-metastore trino spark-master spark-worker
docker compose up -d dagster-postgres dagster-code-location dagster-daemon superset
```

- **Dagster UI**: http://localhost:3000 (jobs: ingest_raw, generate_trades, main_pipeline, soda_quality)
- **Superset UI**: http://localhost:8088 (user/pass `admin`)

Trước khi chạy dbt assets (Dagster): `cd data-platform/dbt && dbt deps && dbt parse` (sinh `target/manifest.json`).

## Bước 5: Kết nối BI - Superset

1. Mở http://localhost:8088 → **Databases** → **+ Database**
2. SQLAlchemy URI: `trino://admin@trino:8080/ssi_report`
3. Scan → 13 datasets từ các view `reporting.rpt_*`, tạo dashboard.

## Bước 6: Query qua Trino

```sql
SELECT * FROM ssi_data.gold.dim_customer FOR VERSION AS OF TIMESTAMP '2027-03-15 10:00:00';
SELECT * FROM ssi_report.reporting.rpt_broker_commission_revenue;
```
