# 📊 DATA CATALOG - SSI Trading Analytics

> Tài liệu mô tả toàn bộ cấu trúc dữ liệu: Database nguồn (SQL Server),
> Data Warehouse (Snowflake 3 layer), API, và các bảng Dim/Fact/Mart.

---

## 1. TỔNG QUAN KIẾN TRÚC DỮ LIỆU

```
┌────────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE - ANALYTICS DB                        │
│                                                                    │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────────┐     │
│  │  BRONZE   │    │  SILVER  │    │         GOLD             │     │
│  │  RAW      │───▶│  STG_*   │───▶│  ┌─────┐  ┌──────┐     │     │
│  │  (VARIANT)│    │ (flatten)│    │  │ dim │  │ fact │     │     │
│  │           │    │          │    │  └──┬──┘  └──┬───┘     │     │
│  └──────────┘    └──────────┘    │     │        │         │     │
│                                  │     └───┬────┘         │     │
│                                  │         ▼               │     │
│                                  │  ┌──────────┐          │     │
│                                  │  │  reports  │          │     │
│                                  │  │ (13 views)│          │     │
│                                  │  └──────────┘          │     │
│                                  └──────────────────────────┘     │
│                                                                    │
│  Nguồn: SQL Server (4 DB) + HR API                                │
│  EL:    Meltano (tap-mssql/tap-hr-api → S3 → Snowflake)          │
│  Transform: dbt Core (staging → dim/fact → reports)               │
│  Quality:  Soda Core (checks trên Gold layer)                     │
│  BI:       Apache Superset (kết nối Snowflake)                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 2. NGUỒN DỮ LIỆU - SQL SERVER (4 DATABASE)

### 2.1. SSI_Common (Dùng chung)

Database chứa dữ liệu tổ chức, nhân sự, khách hàng dùng chung cho cả 3 sản phẩm.

| Bảng                             | PK                       | Mô tả                       | Ghi chú                                     |
| -------------------------------- | ------------------------ | --------------------------- | ------------------------------------------- |
| `branch`                         | branch_id                | Chi nhánh SSI               | director_employee_code → HR API             |
| `department`                     | department_id            | Phòng ban                   | head_employee_code → HR API                 |
| `broker`                         | **broker_code**          | Môi giới / CTV              | broker_type: BROKER / COLLABORATOR          |
| `customer`                       | **customer_code**        | Khách hàng                  | Có id_number (nhạy cảm - bị loại ở staging) |
| `customer_broker_history`        | history_id               | Lịch sử MG chăm sóc KH      | **SCD Type 2** (is_current)                 |
| `customer_risk_profile`          | history_id               | Lịch sử phân loại rủi ro KH | **SCD Type 2** (is_current)                 |
| `customer_segment_history`       | history_id               | Lịch sử phân khúc KH        | **SCD Type 2** (is_current)                 |
| `customer_acquisition`           | customer_code            | Nguồn gốc KH (1 dòng/KH)    | immutable                                   |
| `fee_schedule`                   | fee_schedule_id          | Biểu phí theo sản phẩm      | product_type: EQUITY/DERIVATIVES/OEF        |
| `management_commission_schedule` | schedule_id              | Hoa hồng quản lý            | management_level                            |
| `market_index_price`             | (index_code, price_date) | Giá chỉ số thị trường       | VN-Index, VN30                              |
| `trading_alert`                  | alert_id                 | Cảnh báo giao dịch          | Cross-DB ref tới trade                      |
| `customer_complaint`             | complaint_id             | Khiếu nại khách hàng        | status: OPEN/IN_PROGRESS/RESOLVED/CLOSED    |

### 2.2. SSI_Equity (Chứng khoán cơ sở)

| Bảng                    | PK                                       | Mô tả                     | Ghi chú                                 |
| ----------------------- | ---------------------------------------- | ------------------------- | --------------------------------------- |
| `security`              | security_id                              | Mã chứng khoán            | symbol, exchange: HOSE/HNX/UPCOM        |
| `daily_price`           | (security_id, price_date)                | Giá đóng cửa hàng ngày    | -                                       |
| `account`               | account_id                               | Tài khoản giao dịch       | customer_code → SSI_Common (logical FK) |
| `equity_trade`          | (trade_id, trade_date)                   | **Giao dịch cổ phiếu**    | Partition theo tháng                    |
| `account_balance_daily` | (account_id, balance_date)               | Số dư tài khoản cuối ngày | Partition theo tháng                    |
| `position_daily`        | (account_id, security_id, position_date) | Vị thế nắm giữ            | Partition theo tháng                    |
| `margin_loan_daily`     | (account_id, loan_date)                  | Dư nợ margin              | call_margin_flag                        |

### 2.3. SSI_Derivatives (Phái sinh)

| Bảng                     | PK                                       | Mô tả                    | Ghi chú                                 |
| ------------------------ | ---------------------------------------- | ------------------------ | --------------------------------------- |
| `derivative_contract`    | contract_id                              | Hợp đồng phái sinh       | contract_code: VN30F2701                |
| `daily_settlement_price` | (contract_id, price_date)                | Giá thanh toán hàng ngày | -                                       |
| `account`                | account_id                               | Tài khoản phái sinh      | customer_code → SSI_Common (logical FK) |
| `derivative_trade`       | (trade_id, trade_date)                   | **Giao dịch phái sinh**  | position_side: LONG/SHORT               |
| `account_balance_daily`  | (account_id, balance_date)               | Số dư                    | Partition theo tháng                    |
| `position_daily`         | (account_id, contract_id, position_date) | Vị thế                   | Partition theo tháng                    |
| `margin_loan_daily`      | (account_id, loan_date)                  | Dư nợ margin             | Partition theo tháng                    |

### 2.4. SSI_OEF (Chứng chỉ quỹ mở)

| Bảng                    | PK                                   | Mô tả                | Ghi chú                                   |
| ----------------------- | ------------------------------------ | -------------------- | ----------------------------------------- |
| `fund`                  | fund_id                              | Quỹ mở               | fund_type: EQUITY_FUND/BOND_FUND/BALANCED |
| `fund_nav_history`      | (fund_id, nav_date)                  | NAV hàng ngày        | -                                         |
| `account`               | account_id                           | Tài khoản OEF        | customer_code → SSI_Common (logical FK)   |
| `oef_trade`             | (trade_id, trade_date)               | **Giao dịch quỹ mở** | transaction_type: SUBSCRIBE/REDEEM/SWITCH |
| `account_balance_daily` | (account_id, balance_date)           | Số dư                | Partition theo tháng                      |
| `position_daily`        | (account_id, fund_id, position_date) | Vị thế               | Partition theo tháng                      |

> **Không có margin_loan_daily** trong OEF - chứng chỉ quỹ mở không margin.

---

## 3. HR API

### Endpoint

| Method | Endpoint                               | Mô tả                   |
| ------ | -------------------------------------- | ----------------------- |
| GET    | `/employees`                           | Danh sách nhân viên/CTV |
| GET    | `/employees/{id_number}`               | Chi tiết 1 người        |
| GET    | `/employees/{id_number}/manager-chain` | Chuỗi quản lý cấp trên  |

### Cấu trúc Person (mẫu)

```json
{
  "id_number": "001099000001",
  "employee_code": "NV0001",
  "full_name": "Nguyen Van A",
  "person_type": "EMPLOYEE",
  "branch_code": "CN01",
  "branch_name": "Chi nhanh Ha Noi",
  "department_code": "PB01",
  "department_name": "Phong Moi Gioi Ha Noi",
  "position": "Chuyen vien Moi gioi",
  "position_code": "STANDARD",
  "position_level": "BROKER",
  "manager_employee_code": "NV0003",
  "start_date": "2021-03-01",
  "end_date": null,
  "status": "ACTIVE"
}
```

| Field                   | Mô tả                                                                |
| ----------------------- | -------------------------------------------------------------------- |
| `id_number`             | CCCD - key định danh chính (cả EMPLOYEE và COLLABORATOR đều có)      |
| `employee_code`         | Mã nhân viên HR - chỉ có khi `person_type = EMPLOYEE`                |
| `person_type`           | `EMPLOYEE` (nhân viên chính thức) / `COLLABORATOR` (CTV bên ngoài)   |
| `position_level`        | `BROKER` / `HEAD_OF_DEPARTMENT` / `BRANCH_DIRECTOR` / `COLLABORATOR` |
| `position_code`         | `STANDARD` / `SENIOR` / `TEAM_LEAD` / `RM_VIP` / `REFERRAL_*`        |
| `manager_employee_code` | Người quản lý trực tiếp (chỉ EMPLOYEE)                               |

### Authentication

- `none` (lab) / `api_key` (X-API-Key header) / `jwt` (Bearer token)

---

## 4. SNOWFLAKE - 3 LAYER DATA WAREHOUSE

### 4.1. Layer 1: Bronze (RAW)

Dữ liệu thô dạng VARIANT từ Meltano/S3. Cấu trúc chung:

```sql
CREATE TABLE RAW.<schema>.<table>_RAW (
    raw_data    VARIANT,      -- Toàn bộ dữ liệu gốc dạng JSON
    _file_name  VARCHAR,      -- File Parquet nguồn
    _loaded_at  TIMESTAMP_NTZ -- Thời điểm load
);
```

**RAW tables:**
| Schema | Table | Nguồn |
|--------|-------|-------|
| `RAW.COMMON` | customer_raw, broker_raw, branch_raw, ... | Meltano từ SSI_Common |
| `RAW.EQUITY` | equity_trade_raw, account_balance_raw, ... | Meltano từ SSI_Equity |
| `RAW.DERIVATIVES` | derivative_trade_raw, account_balance_raw, ... | Meltano từ SSI_Derivatives |
| `RAW.OEF` | oef_trade_raw, account_balance_raw, ... | Meltano từ SSI_OEF |
| `RAW.HR` | employee_raw | Meltano từ HR API |

### 4.2. Layer 2: Silver (STG\_\*) - dbt Staging

Dữ liệu đã được **flatten từ VARIANT**, **dedup** (ROW_NUMBER theo source_system + source_trade_id), và **làm sạch**.

| STG Table                            | Nguồn RAW                          | Ghi chú                                      |
| ------------------------------------ | ---------------------------------- | -------------------------------------------- |
| `STG_COMMON.customer`                | common.customer_raw                | Loại bỏ id_number (bảo mật)                  |
| `STG_COMMON.broker`                  | common.broker_raw                  | -                                            |
| `STG_COMMON.branch`                  | common.branch_raw                  | -                                            |
| `STG_COMMON.department`              | common.department_raw              | -                                            |
| `STG_COMMON.customer_broker_history` | common.customer_broker_history_raw | SCD2                                         |
| `STG_EQUITY.equity_trade`            | equity.equity_trade_raw            | **Dedup by source_system + source_trade_id** |
| `STG_EQUITY.account_balance_daily`   | equity.account_balance_raw         | -                                            |
| `STG_EQUITY.position_daily`          | equity.position_raw                | -                                            |
| `STG_EQUITY.margin_loan_daily`       | equity.margin_loan_raw             | -                                            |
| `STG_DERIVATIVES.derivative_trade`   | derivatives.derivative_trade_raw   | **Dedup**                                    |
| `STG_OEF.oef_trade`                  | oef.oef_trade_raw                  | **Dedup**                                    |
| `STG_HR.employee`                    | hr.employee_raw                    | -                                            |

### 4.3. Layer 3: Gold (MARTS) - Star Schema

#### 4.3.1. Dimension Tables

##### dim_customer

| Column                    | Type       | Mô tả                                       | FK           |
| ------------------------- | ---------- | ------------------------------------------- | ------------ |
| `customer_code`           | VARCHAR PK | Mã khách hàng (VD: KH00001)                 | -            |
| `customer_name`           | VARCHAR    | Tên khách hàng                              | -            |
| `customer_type`           | VARCHAR    | INDIVIDUAL / ORGANIZATION / PROPRIETARY     | -            |
| `residency`               | VARCHAR    | DOMESTIC / FOREIGN                          | -            |
| `open_date`               | DATE       | Ngày mở tài khoản                           | -            |
| `is_active`               | BOOLEAN    | Còn hoạt động không                         | -            |
| `current_broker_code`     | VARCHAR    | MG đang chăm sóc (hiện tại)                 | → dim_broker |
| `current_segment`         | VARCHAR    | Phân khúc hiện tại: VIP / PRIORITY / RETAIL | -            |
| `investor_classification` | VARCHAR    | PROFESSIONAL / NON_PROFESSIONAL             | -            |
| `current_risk_level`      | VARCHAR    | LOW / MEDIUM / HIGH                         | -            |
| `acquisition_channel`     | VARCHAR    | Kênh tiếp thị                               | -            |
| `acquisition_date`        | DATE       | Ngày acquired                               | -            |
| `referral_broker_code`    | VARCHAR    | MG giới thiệu                               | → dim_broker |
| `campaign_code`           | VARCHAR    | Mã chiến dịch                               | -            |

##### dim_broker

| Column           | Type       | Mô tả                                       | FK               |
| ---------------- | ---------- | ------------------------------------------- | ---------------- |
| `broker_code`    | VARCHAR PK | Mã môi giới (VD: MG0001)                    | -                |
| `broker_name`    | VARCHAR    | Tên môi giới                                | -                |
| `broker_type`    | VARCHAR    | BROKER / COLLABORATOR                       | -                |
| `broker_subtype` | VARCHAR    | STANDARD / SENIOR / TEAM*LEAD / REFERRAL*\* | -                |
| `department_id`  | INT        | Phòng ban                                   | → dim_department |
| `branch_id`      | INT        | Chi nhánh                                   | → dim_branch     |
| `employee_code`  | VARCHAR    | Mã nhân viên HR                             | → dim_employee   |
| `phone`          | VARCHAR    | SĐT                                         | -                |
| `email`          | VARCHAR    | Email                                       | -                |
| `is_active`      | BOOLEAN    | Đang làm việc                               | -                |

##### dim_account

| Column          | Type       | Mô tả                        | FK             |
| --------------- | ---------- | ---------------------------- | -------------- |
| `product_type`  | VARCHAR PK | EQUITY / DERIVATIVES / OEF   | -              |
| `account_id`    | INT PK     | ID tài khoản (trong product) | -              |
| `account_no`    | VARCHAR    | Số tài khoản                 | -              |
| `customer_code` | VARCHAR    | Mã khách hàng                | → dim_customer |
| `broker_code`   | VARCHAR    | Mã môi giới                  | → dim_broker   |
| `open_date`     | DATE       | Ngày mở                      | -              |

> ⚠️ `(product_type, account_id)` phải dùng cùng nhau - account_id chỉ unique trong 1 product.

##### dim_security

| Column          | Type    | Mô tả                     |
| --------------- | ------- | ------------------------- |
| `security_id`   | INT PK  | ID mã chứng khoán         |
| `symbol`        | VARCHAR | Mã CK (VD: SSI, VNM, FPT) |
| `security_name` | VARCHAR | Tên chứng khoán           |
| `exchange`      | VARCHAR | HOSE / HNX / UPCOM        |
| `sector`        | VARCHAR | Ngành                     |
| `security_type` | VARCHAR | Loại chứng khoán          |

##### dim_derivative_contract

| Column              | Type    | Mô tả                         |
| ------------------- | ------- | ----------------------------- |
| `contract_id`       | INT PK  | ID hợp đồng phái sinh         |
| `contract_code`     | VARCHAR | Mã hợp đồng (VD: VN30F2701)   |
| `underlying_symbol` | VARCHAR | Tài sản cơ sở (VD: VN30)      |
| `contract_type`     | VARCHAR | INDEX_FUTURES                 |
| `multiplier`        | NUMERIC | Hệ số nhân (mặc định 100,000) |
| `maturity_date`     | DATE    | Ngày đáo hạn                  |

##### dim_fund

| Column           | Type    | Mô tả                              |
| ---------------- | ------- | ---------------------------------- |
| `fund_id`        | INT PK  | ID quỹ                             |
| `fund_code`      | VARCHAR | Mã quỹ (VD: SSI_SCF)               |
| `fund_name`      | VARCHAR | Tên quỹ                            |
| `fund_type`      | VARCHAR | EQUITY_FUND / BOND_FUND / BALANCED |
| `fund_manager`   | VARCHAR | Công ty quản lý quỹ                |
| `inception_date` | DATE    | Ngày thành lập                     |

##### dim_branch

| Column                   | Type    | Mô tả                   |
| ------------------------ | ------- | ----------------------- |
| `branch_id`              | INT PK  | ID chi nhánh            |
| `branch_code`            | VARCHAR | Mã chi nhánh (VD: CN01) |
| `branch_name`            | VARCHAR | Tên chi nhánh           |
| `director_employee_code` | VARCHAR | → HR API (logical)      |

##### dim_department

| Column               | Type    | Mô tả              |
| -------------------- | ------- | ------------------ |
| `department_id`      | INT PK  | ID phòng ban       |
| `branch_id`          | INT     | → dim_branch       |
| `department_code`    | VARCHAR | Mã phòng ban       |
| `department_name`    | VARCHAR | Tên phòng ban      |
| `head_employee_code` | VARCHAR | → HR API (logical) |

##### dim_employee (từ HR API)

| Column                  | Type       | Mô tả             |
| ----------------------- | ---------- | ----------------- |
| `employee_code`         | VARCHAR PK | Mã nhân viên HR   |
| `id_number`             | VARCHAR    | CCCD              |
| `full_name`             | VARCHAR    | Họ tên            |
| `position`              | VARCHAR    | Chức danh         |
| `position_level`        | VARCHAR    | Level             |
| `manager_employee_code` | VARCHAR    | Người quản lý     |
| `status`                | VARCHAR    | ACTIVE / INACTIVE |

##### dim_date

| Column        | Type    | Mô tả          |
| ------------- | ------- | -------------- |
| `date_key`    | DATE PK | Ngày           |
| `day_of_week` | INT     | Thứ trong tuần |
| `month`       | INT     | Tháng          |
| `quarter`     | INT     | Quý            |
| `year`        | INT     | Năm            |
| `is_weekend`  | BOOLEAN | Cuối tuần?     |
| `is_holiday`  | BOOLEAN | Ngày lễ?       |

#### 4.3.2. Fact Tables

##### fact_equity_trade (Incremental)

| Column            | Type          | Mô tả                            | FK             |
| ----------------- | ------------- | -------------------------------- | -------------- |
| `product_type`    | VARCHAR       | 'EQUITY'                         | -              |
| `trade_id`        | BIGINT        | **ID giao dịch** (= contract_id) | -              |
| `trade_date`      | DATE          | Ngày giao dịch                   | → dim_date     |
| `trade_datetime`  | TIMESTAMP     | Thời gian giao dịch              | -              |
| `source_trade_id` | VARCHAR       | ID gốc từ hệ thống               | **UNIQUE**     |
| `account_no`      | VARCHAR       | Số tài khoản                     | -              |
| `customer_code`   | VARCHAR       | Mã khách hàng                    | → dim_customer |
| `broker_code`     | VARCHAR       | Mã môi giới                      | → dim_broker   |
| `security_id`     | INT           | Mã chứng khoán                   | → dim_security |
| `market`          | VARCHAR       | HOSE / HNX / UPCOM               | -              |
| `side`            | VARCHAR       | BUY / SELL                       | -              |
| `order_type`      | VARCHAR       | LO / MP / ATO / ATC              | -              |
| `quantity`        | BIGINT        | Khối lượng                       | -              |
| `price`           | NUMERIC(18,2) | Giá                              | -              |
| `amount`          | NUMERIC(20,2) | Giá trị                          | -              |
| `fee_amount`      | NUMERIC(18,2) | Phí giao dịch                    | -              |
| `tax_amount`      | NUMERIC(18,2) | Thuế (nếu SELL)                  | -              |
| `settlement_date` | DATE          | Ngày thanh toán                  | -              |
| `order_id`        | VARCHAR       | Mã lệnh                          | -              |
| `source_system`   | VARCHAR       | Hệ thống gốc                     | -              |
| `ingested_at`     | TIMESTAMP     | Thời điểm ingest                 | -              |

##### fact_derivative_trade (Incremental)

| Column                   | Type          | Mô tả                              | FK                        |
| ------------------------ | ------------- | ---------------------------------- | ------------------------- |
| `product_type`           | VARCHAR       | 'DERIVATIVES'                      | -                         |
| `trade_id`               | BIGINT        | ID giao dịch                       | -                         |
| `trade_date`             | DATE          | Ngày giao dịch                     | → dim_date                |
| `source_trade_id`        | VARCHAR       | ID gốc                             | **UNIQUE**                |
| `contract_id`            | VARCHAR       | **ID hợp đồng phái sinh**          | -                         |
| `account_no`             | VARCHAR       | Số tài khoản                       | -                         |
| `customer_code`          | VARCHAR       | Mã KH                              | → dim_customer            |
| `broker_code`            | VARCHAR       | Mã MG                              | → dim_broker              |
| `derivative_contract_id` | INT           | Hợp đồng phái sinh                 | → dim_derivative_contract |
| `position_side`          | VARCHAR       | LONG / SHORT                       | -                         |
| `order_action`           | VARCHAR       | OPEN / CLOSE                       | -                         |
| `quantity`               | INT           | Khối lượng (hợp đồng)              | -                         |
| `price`                  | NUMERIC(18,2) | Giá                                | -                         |
| `amount`                 | NUMERIC(20,2) | Giá trị (qty _ price _ multiplier) | -                         |
| `margin_amount`          | NUMERIC(20,2) | Ký quỹ                             | -                         |
| `fee_amount`             | NUMERIC(18,2) | Phí                                | -                         |
| `settlement_date`        | DATE          | Ngày thanh toán                    | -                         |
| `source_system`          | VARCHAR       | Hệ thống gốc                       | -                         |
| `ingested_at`            | TIMESTAMP     | Thời điểm ingest                   | -                         |

##### fact_oef_trade (Incremental)

| Column             | Type          | Mô tả                       | FK             |
| ------------------ | ------------- | --------------------------- | -------------- |
| `product_type`     | VARCHAR       | 'OEF'                       | -              |
| `trade_id`         | BIGINT        | ID giao dịch                | -              |
| `trade_date`       | DATE          | Ngày giao dịch              | → dim_date     |
| `source_trade_id`  | VARCHAR       | ID gốc                      | **UNIQUE**     |
| `account_no`       | VARCHAR       | Số tài khoản                | -              |
| `customer_code`    | VARCHAR       | Mã KH                       | → dim_customer |
| `broker_code`      | VARCHAR       | Mã MG                       | → dim_broker   |
| `fund_id`          | INT           | Quỹ                         | → dim_fund     |
| `transaction_type` | VARCHAR       | SUBSCRIBE / REDEEM / SWITCH | -              |
| `quantity_unit`    | NUMERIC(20,4) | Số lượng đơn vị quỹ         | -              |
| `nav_price`        | NUMERIC(18,4) | NAV tại giao dịch           | -              |
| `amount`           | NUMERIC(20,2) | Giá trị                     | -              |
| `fee_amount`       | NUMERIC(18,2) | Phí                         | -              |
| `settlement_date`  | DATE          | Ngày thanh toán             | -              |
| `source_system`    | VARCHAR       | Hệ thống gốc                | -              |
| `ingested_at`      | TIMESTAMP     | Thời điểm ingest            | -              |

##### fact_account_balance_daily (Incremental)

| Column              | Type          | Mô tả                      | FK            |
| ------------------- | ------------- | -------------------------- | ------------- |
| `product_type`      | VARCHAR PK    | EQUITY / DERIVATIVES / OEF | -             |
| `account_id`        | INT PK        | ID tài khoản               | → dim_account |
| `balance_date`      | DATE PK       | Ngày                       | → dim_date    |
| `cash_balance`      | NUMERIC(20,2) | Số dư tiền mặt             | -             |
| `portfolio_value`   | NUMERIC(20,2) | Giá trị danh mục           | -             |
| `total_asset_value` | NUMERIC(20,2) | Tổng tài sản               | -             |

##### fact_position_daily (Incremental)

| Column           | Type          | Mô tả                               | FK            |
| ---------------- | ------------- | ----------------------------------- | ------------- |
| `product_type`   | VARCHAR PK    | EQUITY / DERIVATIVES / OEF          | -             |
| `account_id`     | INT PK        | ID tài khoản                        | → dim_account |
| `instrument_id`  | INT PK        | security_id / contract_id / fund_id | -             |
| `position_date`  | DATE PK       | Ngày                                | → dim_date    |
| `quantity`       | NUMERIC(20,4) | Số lượng nắm giữ                    | -             |
| `avg_cost_price` | NUMERIC(18,4) | Giá vốn trung bình                  | -             |
| `market_value`   | NUMERIC(20,2) | Giá trị thị trường                  | -             |

##### fact_margin_loan_daily (Incremental)

| Column                     | Type          | Mô tả                    |
| -------------------------- | ------------- | ------------------------ |
| `product_type`             | VARCHAR PK    | EQUITY / DERIVATIVES     |
| `account_id`               | INT PK        | ID tài khoản             |
| `loan_date`                | DATE PK       | Ngày                     |
| `margin_loan_balance`      | NUMERIC(20,2) | Dư nợ margin             |
| `margin_ratio`             | NUMERIC(10,4) | Tỷ lệ margin             |
| `maintenance_margin_ratio` | NUMERIC(10,4) | Tỷ lệ ký quỹ duy trì     |
| `call_margin_flag`         | BOOLEAN       | Có cảnh báo call margin? |

> Chỉ có EQUITY và DERIVATIVES - OEF không có margin.

---

## 5. 13 BÁO CÁO PHÂN TÍCH (Reports)

| #   | Report                                | Mô tả chính                   | Nguồn dữ liệu                                           |
| --- | ------------------------------------- | ----------------------------- | ------------------------------------------------------- |
| 1   | `rpt_broker_commission_revenue`       | Hoa hồng môi giới             | fact_equity_trade, fact_derivative_trade, dim_broker    |
| 2   | `rpt_department_branch_ranking`       | Xếp hạng phòng ban/chi nhánh  | fact\_\*\_trade, dim_broker, dim_department, dim_branch |
| 3   | `rpt_broker_performance`              | KPI môi giới                  | fact\_\*\_trade, dim_broker                             |
| 4   | `rpt_trading_activity_summary`        | Tổng quan hoạt động giao dịch | fact\_\*\_trade, dim_date                               |
| 5   | `rpt_aum_summary`                     | AUM (tài sản quản lý)         | fact_account_balance_daily, dim_customer                |
| 6   | `rpt_customer_acquisition_funnel`     | Kênh tiếp thị KH mới          | dim_customer, dim_broker                                |
| 7   | `rpt_customer_dormant`                | KH ngừng giao dịch            | dim*customer, fact*\*\_trade                            |
| 8   | `rpt_position_concentration_risk`     | Rủi ro tập trung danh mục     | fact_position_daily, dim_security                       |
| 9   | `rpt_margin_call_alert`               | Cảnh báo margin call          | fact_margin_loan_daily, dim_account                     |
| 10  | `rpt_oef_fund_flow`                   | Dòng vốn quỹ mở               | fact_oef_trade, dim_fund                                |
| 11  | `rpt_customer_investment_performance` | Hiệu suất đầu tư KH           | fact*position_daily, fact*\*\_trade                     |
| 12  | `rpt_customer_cross_sell`             | Bán chéo sản phẩm             | dim*customer, fact*\*\_trade                            |
| 13  | `rpt_management_override_commission`  | Hoa hồng quản lý điều chỉnh   | dim_management_commission_schedule                      |

---

## 6. FOREIGN KEY MAP (TOÀN BỘ HỆ THỐNG)

```
dim_account.customer_code ──────────→ dim_customer.customer_code
dim_account.broker_code ────────────→ dim_broker.broker_code

fact_equity_trade.customer_code ────→ dim_customer.customer_code
fact_equity_trade.broker_code ──────→ dim_broker.broker_code
fact_equity_trade.security_id ──────→ dim_security.security_id

fact_derivative_trade.customer_code ─→ dim_customer.customer_code
fact_derivative_trade.broker_code ───→ dim_broker.broker_code
fact_derivative_trade.contract_id ───→ dim_derivative_contract.contract_id

fact_oef_trade.customer_code ───────→ dim_customer.customer_code
fact_oef_trade.broker_code ─────────→ dim_broker.broker_code
fact_oef_trade.fund_id ─────────────→ dim_fund.fund_id

fact_account_balance_daily.account_id → dim_account.account_id (+ product_type)
fact_position_daily.account_id ──────→ dim_account.account_id (+ product_type)
fact_margin_loan_daily.account_id ───→ dim_account.account_id (+ product_type)

dim_broker.department_id ───────────→ dim_department.department_id
dim_department.branch_id ────────────→ dim_branch.branch_id

dim_broker.employee_code ───────────→ dim_employee.employee_code (HR API)
dim_employee.manager_employee_code ──→ dim_employee.employee_code
dim_branch.director_employee_code ───→ dim_employee.employee_code (logical)
```

---

## 7. SO SÁNH: NGUỒN (SQL Server) vs MARTS (Snowflake)

| Entity           | SQL Server (Nguồn)                       | Snowflake MARTS (Gold)                      |
| ---------------- | ---------------------------------------- | ------------------------------------------- |
| Customer         | `SSI_Common.raw.customer` (có id_number) | `dim_customer` (đã loại id_number)          |
| Broker           | `SSI_Common.raw.broker`                  | `dim_broker` (gộp HR info)                  |
| Branch           | `SSI_Common.raw.branch`                  | `dim_branch`                                |
| Account          | 3 DB riêng (Equity/Derivatives/OEF)      | `dim_account` (gộp chung + product_type)    |
| Equity Trade     | `SSI_Equity.raw.equity_trade`            | `fact_equity_trade` (incremental)           |
| Derivative Trade | `SSI_Derivatives.raw.derivative_trade`   | `fact_derivative_trade` (incremental)       |
| OEF Trade        | `SSI_OEF.raw.oef_trade`                  | `fact_oef_trade` (incremental)              |
| Balance          | 3 DB riêng                               | `fact_account_balance_daily` (gộp)          |
| Position         | 3 DB riêng                               | `fact_position_daily` (gộp + instrument_id) |
| SCD2 History     | `customer_broker_history`                | `dim_customer_broker_history`               |
| HR Data          | HR API (`/employees`)                    | `dim_employee`                              |

---

## 8. SCD TYPE 2 - CƠ CHẾ LỊCH SỬ

### Các bảng SCD2

```
Bảng gốc (SQL Server)          dbt Staging              dbt Mart
─────────────────              ──────────              ────────
customer_broker_history   →    stg_common__     →    dim_customer_broker_history
                               customer_broker_       (valid_from, valid_to, is_current)
                               history

customer_risk_profile     →    stg_common__     →    (dùng trong dim_customer)
                               customer_risk_profile

customer_segment_history  →    stg_common__     →    (dùng trong dim_customer)
                               customer_segment_history

customer (dbt snapshot)   →    snap_customer_   →    dim_customer_history
                               profile               (dbt_valid_from → valid_from,
                               (SCD2 capture)         dbt_valid_to → valid_to,
                                                      dbt_valid_to IS NULL → is_current)
```

### Cách query lịch sử

```sql
-- Trạng thái hiện tại của KH
SELECT * FROM dim_customer WHERE is_active = true;

-- Ai chăm sóc KH vào ngày cụ thể?
SELECT * FROM dim_customer_broker_history
WHERE customer_code = 'KH00001'
  AND valid_from <= '2026-07-27'
  AND (valid_to IS NULL OR valid_to >= '2026-07-27');

-- Lịch sử thay đổi của KH
SELECT * FROM dim_customer_history
WHERE customer_code = 'KH00001'
ORDER BY valid_from;
```

---

## 9. DỮ LIỆU MẪU (Generate Trading Data DAG)

DAG `generate_trading_data` tự sinh dữ liệu test với FK chính xác:

| Product     | Mỗi ngày  | Format source_trade_id  |
| ----------- | :-------: | ----------------------- |
| EQUITY      | 50 trades | `GEN-EQ-{date}-{NNNN}`  |
| DERIVATIVES | 20 trades | `GEN-DER-{date}-{NNNN}` |
| OEF         | 15 trades | `GEN-OEF-{date}-{NNNN}` |

Dữ liệu được insert vào RAW tables (dạng VARIANT) → dbt staging sẽ flatten + dedup.
