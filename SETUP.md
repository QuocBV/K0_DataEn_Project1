# Hướng dẫn cài đặt Lakehouse Platform

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

Điền: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AIRFLOW_DB_PASSWORD`, `MSSQL_HOST`, `TRINO_*`, ...

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

Ghi lại UUID của 5 connections.

## Bước 4: Khởi chạy Docker Compose

```bash
docker compose up -d hr-api hive-metastore-db hive-metastore trino spark-master spark-worker
docker compose up -d airflow-postgres airflow-init airflow-webserver airflow-scheduler
```

Đợi 1-2 phút cho Trino sẵn sàng (port 8081).

## Bước 5: Cấu hình Airflow UI

1. **Connections**: `airbyte_default` (Airbyte), `spark_default` (spark://spark-master:7077)
2. **Variables**: `airbyte_connection_ids` (JSON map: mssql_common_to_s3, ..., hr_api_to_s3)

Bật 11 DAGs: `generate_trades`, `ingest_raw`, `bronze_etl`, `bronze_soda`, `silver_etl`, `silver_soda`, `gold_dbt`, `gold_quality`, `commission_engine`, `reporting`, `main_pipeline`

## Bước 6: Query qua Trino

```sql
-- Dữ liệu khách hàng có time-travel
SELECT * FROM ssi_data.gold.dim_customer
FOR VERSION AS OF TIMESTAMP '2027-03-15 10:00:00';

-- Báo cáo từ Commission Engine
SELECT * FROM ssi_report.reporting.rpt_broker_commission_revenue;
```
