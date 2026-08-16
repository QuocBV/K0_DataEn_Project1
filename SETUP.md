# Hướng dẫn cài đặt Lakehouse Platform (Dagster + dbt + Trino + Superset, không Spark)

## 0. Yêu cầu trước khi bắt đầu

- Docker + Docker Compose
- SQL Server (localhost:1433) với user `sa`
- AWS S3 buckets: `ssi-data` và `ssi-report`
- Python 3.12 (để chạy script khởi tạo DB)
- [Optional] Airbyte CLI (`abctl`) hoặc chạy Airbyte container

## Bước 1: Tạo file `.env`

```bash
copy .env.example .env
```

Điền các giá trị (mặc định trong file gốc đã đúng cho dev local):

```env
# Dagster
DAGSTER_POSTGRES_PASSWORD=dagster_dev_password

# MSSQL (localhost)
MSSQL_HOST=host.docker.internal
MSSQL_EXPORT_USER=sa
MSSQL_EXPORT_PASSWORD=123456789
MSSQL_SA_PASSWORD=123456789
MSSQL_AIRBYTE_READER_USER=sa
MSSQL_AIRBYTE_READER_PASSWORD=123456789

# AWS S3
AWS_ACCESS_KEY_ID=<your-access-key>
AWS_SECRET_ACCESS_KEY=<your-secret-key>
AWS_REGION=ap-southeast-1
AWS_S3_ENDPOINT=s3.amazonaws.com

# Airbyte connection IDs (tạo trên Airbyte UI, điền UUID sau)
CONN_MSSQL_COMMON=
CONN_MSSQL_EQUITY=
CONN_MSSQL_DERIVATIVES=
CONN_MSSQL_OEF=
CONN_HR_API=
```

## Bước 2: Khởi tạo SQL Server (databases + schema + data mẫu)

Chạy script Python (tự động drop/create 4 DB + chạy DDL):

```bash
python run_sql_scripts.py
```

Seed dữ liệu mẫu (StaticSampleData - ~1000 rows/table, realism cao):

```bash
python -c "import subprocess; files=['Database/StaticSampleData/01_common_sample.sql','Database/StaticSampleData/02_equity_sample.sql','Database/StaticSampleData/03_derivatives_sample.sql','Database/StaticSampleData/04_oef_sample.sql']; [subprocess.run(['sqlcmd','-S','localhost','-U','sa','-P','123456789','-d','master','-i',f,'-b','-I'], check=True) for f in files]; print('OK')"
```

Kiểm tra nhanh (chạy qua sqlcmd hoặc SSMS):

```sql
SELECT COUNT(*) FROM SSI_Common.raw.broker;      -- 300
SELECT COUNT(*) FROM SSI_Equity.raw.equity_trade; -- 6000
```

## Bước 3: Cấu hình Airbyte → S3 raw

Cấu hình **5 sources MSSQL** (SSI_Common, SSI_Equity, SSI_Derivatives, SSI_OEF + HR API) → **1 destination S3** (`ssi-data` bucket, path `raw/{NAMESPACE}/{stream}/`).

Config Octavia đã có sẵn trong `data-platform/airbyte/`:

- `sources/mssql_*.yaml`
- `destinations/s3_raw.yaml`
- `connections/mssql_*_to_s3.yaml`

Sau khi tạo connection trên Airbyte UI, lấy UUID điền vào `.env` (`CONN_MSSQL_*`).

## Bước 4: Khởi chạy Docker Compose

```bash
docker compose --profile tools up -d --build
```

**Các service chạy:**

| Service             | Port | Vai trò                      |
| ------------------- | ---- | ---------------------------- |
| dagster-webserver   | 3000 | Dagster UI + orchestration   |
| dagster-daemon      | -    | Daemon (schedules/sensors)   |
| trino               | 8081 | SQL engine (Iceberg + MSSQL) |
| hive-metastore      | 9083 | Metastore cho Iceberg        |
| superset            | 8088 | BI (13 report)               |
| hr-api              | 8000 | Mock HR API (employees)      |
| dbt (profile tools) | -    | CLI chạy `dbt` thủ công      |

**Lưu ý**: Spark đã bị loại - không có service spark nào trong compose.

## Bước 5: Tạo dbt manifest + chạy transform

```bash
# Tạo target/manifest.json (bắt buộc cho Dagster load assets)
docker compose --profile tools run --rm dbt deps
docker compose --profile tools run --rm dbt parse

# Chạy toàn bộ pipeline (bronze → silver → gold → reporting)
docker compose --profile tools run --rm dbt run
```

Hoặc chạy từ Dagster UI: http://localhost:3000 → Launch `main_pipeline`.

## Bước 6: Kết nối BI - Superset

1. Mở http://localhost:8088 (user/pass `admin`)
2. **Databases** → **+ Database**
3. SQLAlchemy URI: `trino://admin@trino:8080/ssi_report`
4. Scan → 13 datasets từ view `reporting.rpt_*`

## Bước 7: Truy vấn qua Trino

```bash
docker exec project_de-trino-1 trino
```

```sql
-- Kiểm tra MSSQL (nguồn)
SELECT * FROM mssql_common.raw.broker LIMIT 5;

-- Kiểm tra gold trên S3 (Iceberg)
SHOW TABLES FROM ssi_data.gold;

-- Time-travel
SELECT * FROM ssi_data.gold.dim_customer
FOR VERSION AS OF TIMESTAMP '2027-03-15 10:00:00';
```

## Xử lý sự cố

| Vấn đề                    | Cách xử lý                                                                    |
| ------------------------- | ----------------------------------------------------------------------------- |
| Trino không start         | Kiểm tra `docker compose logs trino` - catalog files phải đúng cú pháp        |
| Dagster không load assets | `dbt parse` phải chạy thành công trước (target/manifest.json tồn tại)         |
| Airbyte connection lỗi    | Kiểm tra MSSQL credentials + network (Airbyte phải truy cập `localhost:1433`) |
| Superset không mở UI      | Đợi init (health = starting), sau ~1-2 phút UI sẵn sàng                       |

## Ghi chú về Spark đã loại bỏ

- `data-platform/spark/jobs/*` không còn được dùng trong pipeline
- Thay thế bằng dbt models: `data-platform/dbt/models/staging/bronze/` + `silver/` + `marts/reports/`
