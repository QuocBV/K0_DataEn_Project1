# SSI Trading Analytics - Data Platform v2.0

He thong Data Engineering phuc vu phan tich & bao cao giao dich Chung khoan co so, Phai sinh va
Chung chi quy mo (OEF) cua SSI Securities.

**Kien truc moi:** Meltano (EL) -> S3 (Data Lake) -> Snowflake (Warehouse) -> dbt (Transform) -> Soda (Quality) -> Superset (BI) -> Airflow (Orchestrator).

> **Cai dat lan dau?** Copy .env.example -> .env, dien day du thong tin Snowflake, AWS S3, SQL Server.
> Sau do chay docker compose up -d de khoi dong toan bo stack.

---

## 1. Tong quan kien truc

`
Layer 1: Nguon du lieu
|- SQL Server (4 DB: SSI_Common, Equity, Derivatives, OEF)
|- HR REST API (mock FastAPI)

Layer 2: Ingestion -> Data Lake (Meltano)
|- tap-mssql (4 instances) -> target-s3 -> S3 (Parquet)
|- tap-hr-api (custom Singer) -> target-s3 -> S3 (Parquet)

Layer 3: Data Lake
|- AWS S3 (Parquet, partitioned by date)

Layer 4: Bridge -> Warehouse (Meltano)
|- tap-s3-parquet -> target-snowflake -> Snowflake RAW

Layer 5: Data Warehouse
|- Snowflake (Bronze -> Silver -> Gold)

Layer 6: Transformation (dbt Core)
|- dbt models: staging -> dim/fact -> snapshot -> history -> reports

Layer 7: Data Quality (Soda Core)
|- Soda checks on Gold layer (row_count, duplicate, missing, freshness)

Layer 8: BI Dashboard (Apache Superset)
|- Pre-configured Snowflake connections

Layer 9: Orchestration (Apache Airflow)
|- 3 DAGs: meltano_extract -> dbt_transform -> soda_checks

Layer 10: DevOps (GitHub Actions + Docker)
|- CI pipeline: validate -> docker_build -> dbt_docs -> soda_validate
`

---

## 2. Cau truc thu muc

`
project-root/
|- docker-compose.yml              # 10 services (hr-api, airflow, meltano, dbt, superset, sqlserver)
|- .env.example                    # Template for secrets
|- .github/workflows/
|   |- pipeline_ci.yml             # CI/CD: validate -> build -> docs -> soda check
|
|- Database/                       # Schema nguon SQL Server (unchanged)
|
|- hr-api/                         # Mock HR API (FastAPI, unchanged)
|
|- data-platform/
|   |- airflow/
|   |   |- Dockerfile              # Cosmos + Soda + Meltano + custom tap installed
|   |   |- requirements.txt
|   |   |- dags/
|   |       |- _common.py
|   |       |- meltano_extract.py  # 5 extracts parallel -> S3 -> Snowflake
|   |       |- dbt_transform.py    # Cosmos DbtTaskGroup (6 stages, data-aware)
|   |       |- soda_checks.py      # Soda scan on Gold layer
|   |
|   |- meltano/
|   |   |- Dockerfile
|   |   |- meltano.yml             # 5 taps + 2 targets + 6 jobs
|   |   |- extractors/tap_hr_api/ # Custom Singer tap
|   |       |- tap.py, streams.py, setup.py, __init__.py
|   |
|   |- dbt/                        # dbt project (unchanged logic)
|   |
|   |- soda/
|   |   |- configuration.yml       # Snowflake connection
|   |   |- checks/
|   |       |- gold_marts_checks.yml  # 10+ quality checks
|   |
|   |- superset/
|   |   |- superset_config.py      # Snowflake DB config, feature flags
|   |
|   |- scripts/                    # Legacy export scripts
|   |- snowflake/                  # Setup SQL scripts (unchanged)
`

---

## 3. Pipeline chi tiet

### 3.1. Extract (Meltano -> S3)

5 pipeline song song, moi pipeline chay trong task rieng cua Airflow:

| Task | Tap | Target | Mo ta |
|---|---|---|---|
| extract_common | tap-mssql-common | target-s3 | Dimension tables (broker, branch, customer, ...) |
| extract_equity | tap-mssql-equity | target-s3 | Equity trades, positions, balances |
| extract_derivatives | tap-mssql-derivatives | target-s3 | Derivative trades, contracts |
| extract_oef | tap-mssql-oef | target-s3 | OEF trades, fund NAV |
| extract_hr | tap-hr-api (custom) | target-s3 | Employee data from HR API |

### 3.2. Load (S3 -> Snowflake)

- **Meltano job:** tap-s3-parquet -> target-snowflake (load all Parquet files into ANALYTICS.RAW)

### 3.3. Transform (dbt Core, orchestrated by Cosmos)

Thu tu bat buoc:
1. staging - build staging views (flatten + dedup)
2. marts_base - build dim/fact (exclude dim_customer_history)
3. snapshot - run dbt snapshot (capture SCD2 state of dim_customer)
4. dim_customer_history - build history table based on snapshot
5. reports - build report views (13 reports)
6. tests - run dbt test on marts + snapshots

### 3.4. Data Quality (Soda Core)

Kiem tra tren Gold layer (ANALYTICS.MARTS): row_count > 0, duplicate_count = 0, missing_count = 0.

### 3.5. BI Dashboard (Apache Superset)

- Pre-configured 3 Snowflake connections (RAW/STAGING/MARTS)
- Truy cap tai http://localhost:8088

---

## 4. DAGs Airflow (Data-aware Scheduling)

| DAG | Schedule | Mo ta |
|---|---|---|
| meltano_extract | 0 2 * * * | Extract -> S3 -> Snowflake |
| dbt_transform | Dataset EXTRACT_DONE | Transform RAW -> MARTS |
| soda_checks | Dataset TRANSFORM_DONE | Quality checks |

---

## 5. Chay bang Docker

`ash
cp .env.example .env
docker compose up -d
# Airflow: http://localhost:8080
# Superset: http://localhost:8088
docker compose run --rm meltano run extract_hr
docker compose run --rm dbt run --select stg_common
`

---

## 6. CI/CD (GitHub Actions)

4 jobs: validate -> docker_build -> dbt_docs -> soda_validate.
Trigger: push/PR vao nhanh main, develop co thay doi trong data-platform/.

---

## 7. Custom Tap HR API

data-platform/meltano/extractors/tap_hr_api/ la Singer tap tuy chinh cho HR REST API.

### Streams
- **employees**: Full refresh, goi GET /employees
- **manager_chain**: Can context tu parent stream

### Authentication
- none, api_key, jwt (cau hinh qua .env)

---

## 8. Luu y bao mat & tuan thu

- customer.id_number (CMND/CCCD/MST) bi loai bo ngay tu tang staging
- Credential doc tu .env (gitignored)
- Docker containers chay non-root

---

## 9. 13 Bao cao phan tich

| # | Report |
|---|--------|
| 1 | rpt_broker_commission_revenue |
| 2 | rpt_department_branch_ranking |
| 3 | rpt_broker_performance |
| 4 | rpt_trading_activity_summary |
| 5 | rpt_aum_summary |
| 6 | rpt_customer_acquisition_funnel |
| 7 | rpt_customer_dormant |
| 8 | rpt_position_concentration_risk |
| 9 | rpt_margin_call_alert |
| 10 | rpt_oef_fund_flow |
| 11 | rpt_customer_investment_performance |
| 12 | rpt_customer_cross_sell |
| 13 | rpt_management_override_commission |

---

## 10. So sanh voi kien truc cu (Airbyte)

| Thanh phan | Cu (v1) | Moi (v2) |
|---|---|---|
| Extract | Airbyte JDBC Connectors | Meltano + Singer taps |
| Data Lake | Khong | AWS S3 (Parquet) |
| Bridge S3 -> Snowflake | Snowpipe / COPY INTO | Meltano |
| Orchestrator | Airflow (PythonOperators) | Airflow + Cosmos + Datasets |
| Data Quality | dbt test (co ban) | Soda Core |
| BI | N/A | Apache Superset |
| CI/CD | Manual | GitHub Actions (4 jobs) |
| HR API Connector | Airbyte low-code (yaml) | Custom Singer tap (Python) |
