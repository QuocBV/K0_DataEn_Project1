# Hướng dẫn cài đặt & khởi chạy Lakehouse Platform

Làm theo đúng thứ tự các bước dưới đây. Mỗi bước phụ thuộc vào bước trước.

## 0. Yêu cầu trước khi bắt đầu

- Docker + Docker Compose
- 1 SQL Server instance (local qua Docker hoặc instance công ty)
- 1 tài khoản AWS S3 với bucket: `ssi-raw`, `ssi-bronze`, `ssi-silver`, `ssi-gold`
- Airbyte (cài qua `abctl local install`)
- `sqlcmd` hoặc SSMS/Azure Data Studio

---

## Bước 1: Tạo file `.env` và điền thông tin

```
cp .env.example .env
```

| Biến                            | Điền gì                              | Lấy ở đâu       |
| ------------------------------- | ------------------------------------ | --------------- |
| `AIRFLOW_DB_PASSWORD`           | Mật khẩu Postgres nội bộ của Airflow | Bạn tự đặt      |
| `AWS_ACCESS_KEY_ID`             | AWS access key                       | AWS IAM console |
| `AWS_SECRET_ACCESS_KEY`         | AWS secret key                       | AWS IAM console |
| `AWS_REGION`                    | Region, vd `ap-southeast-1`          | AWS console     |
| `MSSQL_HOST`                    | Host:port SQL Server                 | Tùy môi trường  |
| `TRINO_USER` / `TRINO_PASSWORD` | User Trino (dev: `admin`)            | Bạn tự đặt      |

---

## Bước 2: Khởi tạo 4 database SQL Server

```bash
docker compose --profile sqlserver up -d sqlserver

sqlcmd -S localhost,1433 -U sa -P <MSSQL_SA_PASSWORD> -d master -i Database/00_create_databases.sql
sqlcmd -S localhost,1433 -U sa -P <MSSQL_SA_PASSWORD> -d master -i Database/Common/run_common.sql
sqlcmd -S localhost,1433 -U sa -P <MSSQL_SA_PASSWORD> -d master -i Database/Equity/run_equity.sql
sqlcmd -S localhost,1433 -U sa -P <MSSQL_SA_PASSWORD> -d master -i Database/Derivatives/run_derivatives.sql
sqlcmd -S localhost,1433 -U sa -P <MSSQL_SA_PASSWORD> -d master -i Database/OEF/run_oef.sql
```

---

## Bước 3: Cài đặt Airbyte + tạo kết nối trên UI

```bash
curl -LsfS https://get.airbyte.com | bash -
abctl local install
```

Sau khi cài, Airbyte UI chạy ở `http://localhost:8000`. **Tạo thủ công trên UI**:

1. **Sources**: MSSQL (common, equity, derivatives, oef) + HR API
2. **Destination**: S3 (format Parquet, bucket: `ssi-raw`, path pattern: `{source}/{table}/{date}/`)
3. **Connections**: 5 connections mapping mỗi source → S3 destination

Ghi lại UUID của từng connection để dùng ở Bước 5.

---

## Bước 4: Khởi chạy Docker Compose

```bash
docker compose up -d hr-api hive-metastore-db hive-metastore trino spark-master spark-worker
```

Đợi 1-2 phút cho Hive Metastore và Trino sẵn sàng.

```bash
docker compose up -d airflow-postgres airflow-init airflow-webserver airflow-scheduler
```

---

## Bước 5: Cấu hình Airflow thủ công (trên UI)

Mở `http://localhost:8080`, đăng nhập với `AIRFLOW_ADMIN_USER`/`AIRFLOW_ADMIN_PASSWORD`.

1. **Admin → Connections → +**: `airbyte_default` (Airbyte, Host = `host.docker.internal`, Port = 8000)
2. **Admin → Connections → +**: `spark_default` (Spark, Host = `spark://spark-master`, Port = 7077)
3. **Admin → Variables → +**: `airbyte_connection_ids` (JSON map resource_name → UUID từ Bước 3):
   ```json
   {
     "mssql_common_to_s3": "<uuid>",
     "mssql_equity_to_s3": "<uuid>",
     "mssql_derivatives_to_s3": "<uuid>",
     "mssql_oef_to_s3": "<uuid>",
     "hr_api_to_s3": "<uuid>"
   }
   ```

Bật 11 DAGs trong Airflow UI (toggle ON):

- `generate_trades` (chạy trước, sinh giao dịch cho ngày)
- `ingest_raw`, `bronze_etl`, `bronze_soda`, `silver_etl`, `silver_soda`
- `gold_dbt`, `gold_quality`, `business_processing`, `reporting`
- `main_pipeline` (được trigger tự động bởi `generate_trades` qua Dataset)

---

## Bước 6: Chạy dbt lần đầu

```bash
cd data-platform/dbt
cp profiles.yml.example profiles.yml
export TRINO_HOST=localhost
export TRINO_PORT=8081
export TRINO_USER=admin
export TRINO_PASSWORD=

dbt deps
dbt run --select path:models/marts --exclude dim_customer_history
dbt snapshot
dbt run --select dim_customer_history
dbt test --select path:models/marts path:snapshots
```

---

## Bước 7: Kiểm tra toàn hệ thống

1. Trigger DAG `main_pipeline` → cả 9 stage chạy tuần tự
2. Kiểm tra Trino: `SELECT * FROM gold.gold.broker_kpi LIMIT 10`
3. Kiểm tra S3: `aws s3 ls s3://ssi-raw/common/broker/`

---

## Xử lý sự cố thường gặp

| Triệu chứng                                                 | Nguyên nhân                                                            |
| ----------------------------------------------------------- | ---------------------------------------------------------------------- |
| DAG `ingest_raw` lỗi "Connection airbyte_default not found" | Chưa tạo Connection ở Bước 5 mục 1                                     |
| DAG lỗi `KeyError` cho `airbyte_connection_ids`             | Chưa tạo Variable ở Bước 5 mục 3                                       |
| Spark job lỗi S3                                            | Kiểm tra `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` trong `.env`      |
| Trino không thấy bảng Iceberg                               | Kiểm tra Hive Metastore đã chạy (`docker compose logs hive-metastore`) |
| dbt lỗi kết nối Trino                                       | Kiểm tra `TRINO_HOST`/`TRINO_PORT` trong profiles.yml                  |
