# SSI Trading Analytics - Lakehouse Platform

Hệ thống Data Engineering phục vụ phân tích & báo cáo giao dịch Chứng khoán cơ sở, Phái sinh và
Chứng chỉ quỹ mở (OEF) của SSI Securities. Kiến trúc **Lakehouse** trên AWS S3 với Apache Iceberg.

> **Cài đặt lần đầu?** Xem **[`SETUP.md`](SETUP.md)** - hướng dẫn từng bước cài đặt.
>
> **Chi tiết schema dữ liệu nguồn?** Xem **[`Database/DATA_MODEL.md`](Database/DATA_MODEL.md)**.

## Kiến trúc tổng quan

```text
SQL Server (4 DB)                        S3 Iceberg Lakehouse
┌─────────────┐     Airbyte              ┌───────────────┐
│ Dimension    │ ───────────────────────▶│ Raw (Parquet)  │
│ tables       │                         └───────┬───────┘
└─────────────┘                                  │ Spark Bronze
┌─────────────┐     Airbyte              ┌───────▼───────┐
│ Heavy trade/ │ ───────────────────────▶│ Bronze Iceberg │
│ snapshot     │                         └───────┬───────┘
└─────────────┘                                  │ Soda Quality
HR API ───────▶ Airbyte (low-code)       ┌───────▼───────┐
                                                 │ Silver Iceberg │
                                                 └───────┬───────┘
                                                         │ Soda Quality
                                                 ┌───────▼───────┐
                                                 │ dbt + Trino   │
                                                 │ (dim / fact)  │
                                                 └───────┬───────┘
                                                         │
                                            ┌────────────▼────────────┐
                                            │  dbt Test + Soda Gold   │
                                            └────────────┬────────────┘
                                                         │
                                            ┌────────────▼────────────┐
                                            │  Spark Business         │
                                            │  (KPI / ranking /       │
                                            │   scoring)              │
                                            └────────────┬────────────┘
                                                         │
                                            ┌────────────▼────────────┐
                                            │  dbt Reporting          │
                                            │  (13 report views)     │
                                            └────────────┬────────────┘
                                                         │
                                                    ┌────▼────┐
                                                    │  Trino  │
                                                    │  → BI   │
                                                    └─────────┘
```

## Technology Stack

| Layer          | Technology             |
| -------------- | ---------------------- |
| Storage        | Amazon S3              |
| Table Format   | Apache Iceberg         |
| Ingestion      | Airbyte                |
| Orchestration  | Apache Airflow         |
| ETL Processing | Apache Spark (PySpark) |
| Data Modeling  | dbt + Trino            |
| SQL Engine     | Trino                  |
| Data Quality   | Soda                   |
| Source DB      | SQL Server             |
| HR API         | FastAPI (mock)         |

## Design Principles

1. **Store all data in S3 using Iceberg tables** - Bronze, Silver, Gold layers.
2. **Airflow orchestrates only** - it never processes data; triggers Airbyte, Spark, dbt, Soda.
3. **Spark handles ETL and complex business processing** - Bronze (schema validation, cast, metadata),
   Silver (clean, dedup, enrich), Business (KPI, ranking, scoring).
4. **dbt handles data modeling and reporting** - dim/fact via Trino on Gold layer.
5. **Trino provides SQL access** to all Iceberg tables for BI tools.
6. **Soda validates data quality** after each processing layer (Bronze → Silver → Gold).
7. **All data is cataloged via Hive Metastore** - Spark and Trino share the same Iceberg catalog.

## Cấu trúc thư mục

```
Database/                  Schema nguồn SQL Server (OLTP, raw/source layer)
  00_create_databases.sql
  Common/ Equity/ Derivatives/ OEF/ StaticSampleData/
  DATA_MODEL.md

hr-api/                    FastAPI trả về dữ liệu HR tĩnh (mock)

data-platform/             Pipeline Lakehouse
  airbyte/                 Tham khảo cấu hình Airbyte (tự tạo trên UI)
  airflow/dags/            9 DAGs điều phối toàn bộ pipeline
  spark/jobs/              PySpark jobs: bronze_etl, silver_etl, business_processing
  dbt/                     dbt models: marts (dim/fact/reports) via Trino
  soda/checks/             Soda checks cho Bronze, Silver, Gold layers
  soda/configuration.yml   Kết nối Soda → Trino
  trino/catalog/           Trino Iceberg catalog config (Hive Metastore + S3)

docker-compose.yml         Chạy local: hr-api + Airflow + Hive Metastore + Trino + Spark + dbt
```

## 9 Airflow DAGs

| #   | DAG                   | Mô tả                                                                          |
| --- | --------------------- | ------------------------------------------------------------------------------ |
| 1   | `ingest_raw`          | Trigger Airbyte sync MSSQL + HR API → S3 Raw Parquet                           |
| 2   | `bronze_etl`          | Spark: S3 Raw → parse/cast/metadata → Bronze Iceberg                           |
| 3   | `bronze_soda`         | Soda: schema, null, duplicate, freshness checks                                |
| 4   | `silver_etl`          | Spark: Bronze → clean/dedup/enrich → Silver Iceberg                            |
| 5   | `silver_soda`         | Soda: FK, missing, distribution, business validation                           |
| 6   | `gold_dbt`            | dbt + Trino: Silver → dim/fact (Gold Iceberg)                                  |
| 7   | `gold_quality`        | dbt test + Soda: unique, relationship, accepted values                         |
| 8   | `business_processing` | Spark: KPI, ranking, scoring → Business Fact Iceberg                           |
| 0   | `generate_trades`     | Spark: sinh giao dịch (Equity/Derivatives/OEF) dựa trên dữ liệu thật từ Silver |
| 9   | `reporting`           | dbt: Business Facts → 13 reporting views                                       |
| -   | `main_pipeline`       | Pipeline tổng: chain 9 DAGs, trigger bởi `generate_trades`                     |

## 13 Báo cáo phân tích

Trong `data-platform/dbt/models/marts/reports/` (giữ nguyên từ kiến trúc cũ):

| #   | Report                                | Mục đích                                                  |
| --- | ------------------------------------- | --------------------------------------------------------- |
| 1   | `rpt_broker_commission_revenue`       | Hoa hồng & doanh số theo Môi giới/CTV/phòng ban/chi nhánh |
| 2   | `rpt_department_branch_ranking`       | Xếp hạng phòng ban/chi nhánh                              |
| 3   | `rpt_broker_performance`              | Đánh giá CTV/Môi giới                                     |
| 4   | `rpt_trading_activity_summary`        | Hiệu quả giao dịch                                        |
| 5   | `rpt_aum_summary`                     | AUM theo khách hàng/môi giới/chi nhánh                    |
| 6   | `rpt_customer_acquisition_funnel`     | Khách hàng mới & funnel                                   |
| 7   | `rpt_customer_dormant`                | Khách hàng dormant/churn                                  |
| 8   | `rpt_position_concentration_risk`     | Rủi ro tập trung danh mục                                 |
| 9   | `rpt_margin_call_alert`               | Cảnh báo margin                                           |
| 10  | `rpt_oef_fund_flow`                   | Dòng tiền quỹ OEF                                         |
| 11  | `rpt_customer_investment_performance` | Hiệu suất đầu tư KH                                       |
| 12  | `rpt_customer_cross_sell`             | Cross-sell 3 mảng sản phẩm                                |
| 13  | `rpt_management_override_commission`  | Hoa hồng quản lý                                          |

## Lưu ý bảo mật & tuân thủ

- `customer.id_number` (CMND/CCCD/MST) **không được đưa vào tầng phân tích** - bị loại bỏ ở Silver ETL.
- Toàn bộ credential lấy qua env/vault, không hardcode.
- Code do AI sinh ra cần được peer review theo Secure SDLC trước khi merge.
