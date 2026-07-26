# SSI Trading Analytics - Data Platform

Hệ thống Data Engineering phục vụ phân tích & báo cáo giao dịch Chứng khoán cơ sở, Phái sinh và
Chứng chỉ quỹ mở (OEF) của SSI Securities. Bao gồm: schema nguồn (OLTP, SQL Server), HR API, và
pipeline ELT (Airbyte + Airflow + Snowflake + dbt).

> **Cài đặt lần đầu?** Xem **[`SETUP.md`](SETUP.md)** - hướng dẫn từng bước điền `.env`, khởi tạo
> SQL Server/Snowflake/Airbyte/Airflow và các lệnh cần chạy để lên được toàn bộ hệ thống.

> Toàn bộ dữ liệu mô tả trong `Database/` là **data gốc** (raw/source), mirror trực tiếp từ các hệ
> thống nghiệp vụ khác (core trading, derivatives, OEF, CRM, HR), **chưa qua ETL/transform**. Các
> bước transform (staging → dim/fact → report) được xây dựng riêng trong `data-platform/dbt/`.

## Tổng quan dự án

**Bài toán.** SSI cần một nền tảng dữ liệu tập trung để phân tích và báo cáo hoạt động giao dịch
trên cả 3 mảng nghiệp vụ - Chứng khoán cơ sở, Phái sinh, Chứng chỉ quỹ mở (OEF) - đồng thời gắn kết
với cơ cấu tổ chức (Chi nhánh → Phòng ban → Môi giới/Cộng tác viên) và đối tượng khách hàng mà từng
môi giới/CTV đang chăm sóc. Ngoài báo cáo hoa hồng/doanh số cơ bản, hệ thống còn phải phục vụ đánh
giá phòng ban/chi nhánh, đánh giá hiệu quả từng môi giới/CTV, AUM, rủi ro tập trung danh mục, cảnh
báo margin, dòng tiền quỹ OEF, hiệu suất đầu tư khách hàng so với benchmark, và cross-sell.

**Phạm vi giải quyết**, xây dựng theo đúng vòng đời dữ liệu từ nguồn đến báo cáo:

1. **Thiết kế schema nguồn** (`Database/`) - 4 database SQL Server tách theo sản phẩm (dùng chung 1
   database Common cho tổ chức/môi giới/khách hàng), đại diện cho dữ liệu OLTP mirror từ các hệ
   thống nghiệp vụ thật (chưa qua ETL). Đây là tầng "raw/source" - nền cho mọi thứ phía sau.
2. **Tích hợp HR** (`hr-api/`) - thông tin nhân viên (môi giới, trưởng phòng, giám đốc chi nhánh)
   được tách khỏi DB giao dịch, lấy qua 1 REST API riêng (hiện là mock tĩnh, sau thay bằng hệ thống
   HR thật mà không cần đổi schema giao dịch).
3. **Sinh dữ liệu mẫu ở quy mô thật** (`*_seed_at_scale.sql`) - 300 môi giới/CTV, 1000 khách hàng,
   hàng triệu giao dịch/tháng trải 6 tháng đầu năm 2027, với phân bố lệch (long-tail) và đặc thù
   riêng của từng loại giao dịch - đủ lớn và đủ thực tế để kiểm chứng các báo cáo có ý nghĩa, không
   phải dữ liệu random vô nghĩa.
4. **Pipeline ELT** (`data-platform/`) - Airbyte (Extract-Load), Snowflake (Stage), Airflow (điều
   phối), dbt (Transform: staging → dim/fact → report). Có tính đến bài toán tối ưu/chống lỗi khi
   khối lượng giao dịch lớn (xem mục 3 bên dưới).
5. **13 báo cáo phân tích** (dbt marts/reports) - từ hoa hồng/doanh số đến rủi ro, AUM, hiệu suất
   đầu tư, cross-sell (xem bảng đầy đủ ở mục 4).
6. **Đóng gói chạy được** (`Dockerfile` + `docker-compose.yml`) cho hr-api, Airflow, dbt.

**Các quyết định thiết kế đáng chú ý** (lý do nằm ngay trong comment của từng file liên quan):
- Khóa chính của môi giới/khách hàng là **mã string nghiệp vụ** (`broker_code`, `customer_code`),
  không phải id số surrogate - vì đây vốn là tham chiếu logic xuyên 4 database (SQL Server không hỗ
  trợ FOREIGN KEY liên database).
- Lịch sử phân công môi giới chăm sóc khách hàng, phân loại rủi ro, phân khúc khách hàng đều là
  **SCD Type 2** (còn nguyên lịch sử theo thời gian), không ghi đè.
- Bảng giao dịch/snapshot lớn **không đi qua Airbyte JDBC** mà export Parquet + nạp bằng Snowpipe -
  nhanh hơn và an toàn hơn khi khối lượng lên tới hàng triệu dòng/tháng.
- Dữ liệu nhạy cảm (`id_number` của khách hàng) bị loại khỏi tầng phân tích ngay từ staging.

**Giới hạn cần biết**: đây là toàn bộ mã nguồn/kiến trúc do AI sinh ra trong phiên làm việc này,
**chưa được chạy thử trên hạ tầng thật** (SQL Server/Snowflake/Airflow/Docker thật) và cần review
theo Secure SDLC trước khi dùng cho bất kỳ mục đích nào ngoài tham khảo/phát triển tiếp (xem mục
"Lưu ý bảo mật & tuân thủ" ở cuối file).

## Quy ước & bất biến quan trọng (đọc trước khi sửa code)

Phần này dành cho bất kỳ ai (người hoặc AI agent) đọc lại repo này sau và cần sửa/mở rộng code -
tóm tắt những điều **không hiển nhiên nếu chỉ đọc lướt từng file riêng lẻ**:

- **Khóa môi giới/khách hàng là string, không phải số.** `broker.broker_code` (vd `MG0001`) và
  `customer.customer_code` (vd `KH00001`) là PRIMARY KEY. Không còn cột `customer_id`/`broker_id`
  kiểu INT ở bất kỳ đâu trong `Database/` hay `data-platform/dbt/models/` - nếu gặp tên cột đó
  trong code, đó là lỗi cần sửa (không phải cố ý). Ngược lại, `account_id`, `security_id`,
  `contract_id`, `fund_id`, `trade_id`, `history_id`, `alert_id`, `complaint_id`... vẫn là surrogate
  key INT/BIGINT IDENTITY bình thường - chỉ riêng khóa môi giới/khách hàng đổi sang string.
- **`account_id` chỉ duy nhất TRONG 1 database sản phẩm.** `SSI_Equity.account_id = 1` và
  `SSI_Derivatives.account_id = 1` là 2 tài khoản khác nhau. Mọi join/so sánh account phải kèm
  `product_type` (xem comment đầu `dbt/models/marts/dim/dim_account.sql`).
- **4 database SQL Server không có FOREIGN KEY liên database** (SSI_Common, SSI_Equity,
  SSI_Derivatives, SSI_OEF là 4 database riêng biệt trên cùng 1 server - SQL Server không hỗ trợ
  FK xuyên database). Mọi cột `customer_code`/`broker_code` trong 3 DB sản phẩm là **tham chiếu
  logic** sang `SSI_Common`, tự kiểm soát ở tầng ETL/ứng dụng, không được DB validate hộ.
- **Quy ước đặt tên file SQL trong `Database/<DB>/`**: số 2 chữ số ở đầu tên file = thứ tự chạy
  (được liệt kê đúng thứ tự trong `run_*.sql` của thư mục đó). `*_seed_sample_data.sql` (dữ liệu ví
  dụ nhỏ, viết tay), `*_seed_at_scale.sql` (dữ liệu quy mô lớn, sinh bằng script T-SQL lúc chạy) và
  `Database/StaticSampleData/*.sql` (dữ liệu ~1000 dòng/tháng/bảng, sinh 1 lần bằng Python thành câu
  INSERT tĩnh) là **3 lựa chọn loại trừ nhau** - chạy đúng 1 trong 3, không chạy nhiều hơn 1 (sẽ đụng
  unique constraint vì cùng tạo dữ liệu từ đầu).
- **dbt materialization**: `staging/*` = view, `marts/dim/*` và `marts/fact/*` = table (fact dùng
  `materialized='incremental'` với `unique_key`), `marts/reports/*` = view (luôn phản ánh dữ liệu
  mới nhất). Schema Snowflake của staging đặt tên `STG_<DOMAIN>` qua macro tùy chỉnh
  `macros/generate_schema_name.sql` (không dùng quy ước mặc định của dbt).
- **`raw.customer.id_number`** (CMND/CCCC/MST) tồn tại trong DDL nguồn nhưng **bị loại bỏ có chủ ý**
  ngay từ `stg_common__customer.sql` trở lên - không thêm lại cột này vào bất kỳ model dbt nào phía
  trên staging (lý do: dữ liệu định danh cá nhân, xem mục bảo mật cuối file).
- **Dữ liệu snapshot theo ngày** (`account_balance_daily`, `position_daily`, `margin_loan_daily`)
  trong các script `*_seed_at_scale.sql` được **sinh độc lập** (random walk hợp lý theo từng tài
  khoản), không đối chiếu chính xác với sổ lệnh giao dịch (`equity_trade`/`derivative_trade`/
  `oef_trade`) trong cùng script - đây là giới hạn có chủ đích của dữ liệu test, không phải bug.

## Cấu trúc thư mục

```
Database/           Schema nguồn SQL Server (OLTP, raw/source layer)
  00_create_databases.sql
  Common/            SSI_Common   - to chuc, moi gioi/CTV, khach hang, phan loai, phi, tuan thu
  Equity/            SSI_Equity   - danh muc CK, giao dich co so, account/position/margin
  Derivatives/       SSI_Derivatives - danh muc hop dong, giao dich phai sinh, account/position/margin
  OEF/               SSI_OEF      - danh muc quy, giao dich CCQ, account/position
  StaticSampleData/  Bo du lieu mau thu 3: INSERT tinh (~1000 dong/thang/bang), xem muc 1 ben duoi
  run_all.sql        Chay toan bo 4 DB theo dung thu tu

hr-api/              FastAPI tra ve du lieu HR tinh (static/mock) cho Moi gioi - thay the sau bang
                      he thong HR that ma khong doi schema phia tren

data-platform/        Pipeline ELT: Airbyte (EL) -> Snowflake (Stage) -> dbt (Transform)
  airbyte/            Octavia CLI config: sources, destinations, connections
  airflow/            DAGs dieu phoi toan bo qua trinh ELT
  scripts/            Export partition SQL Server -> Parquet (cho cac bang giao dich nang)
  snowflake/          Setup warehouse/role/database/schema + bulk-load (Snowpipe/COPY INTO)
  dbt/                staging -> marts (dim/fact/reports)

docker-compose.yml    Chay local: hr-api + Airflow + dbt (xem muc "Chay bang Docker" ben duoi)
```

## 1. Database (SQL Server, OLTP nguồn)

> Mô tả đầy đủ schema, sơ đồ quan hệ (ER diagram) và bảng tổng hợp FK/logical reference của cả 4
> database: xem **[`Database/DATA_MODEL.md`](Database/DATA_MODEL.md)**.

### Đối tượng & kiến trúc

- **Chi nhánh → Phòng ban → Môi giới/CTV → Khách hàng**: `SSI_Common` (dùng chung cho cả 3 sản phẩm).
- **Khóa là mã string, không phải số surrogate**: `broker.broker_code` (vd `MG0001`) và
  `customer.customer_code` (vd `KH00001`) là PRIMARY KEY trực tiếp - mọi bảng tham chiếu (kể cả
  3 DB sản phẩm) lưu thẳng mã này thay vì id số. Lý do: mã là định danh nghiệp vụ thật từ hệ thống
  nguồn, ổn định hơn số auto-increment khi đây vốn đã là **tham chiếu logic** xuyên database (SQL
  Server không hỗ trợ FOREIGN KEY giữa các database khác nhau).
- **Môi giới (`BROKER`)** gắn với 1 nhân viên HR (`employee_code`), chia theo `broker_subtype`:
  `STANDARD` / `SENIOR` / `TEAM_LEAD` / `RM_VIP`. **Cộng tác viên (`COLLABORATOR`)** không bắt buộc
  có mã nhân viên, chia theo `broker_subtype`: `REFERRAL_INDIVIDUAL` / `REFERRAL_AFFILIATE` /
  `REFERRAL_INSTITUTIONAL`.
- **Khách hàng** chia theo `customer_type` (`INDIVIDUAL` / `ORGANIZATION` / `PROPRIETARY` - tự
  doanh) kết hợp `residency` (`DOMESTIC` / `FOREIGN`) - khớp đúng 4 nhóm NĐT chuẩn UBCKNN/HOSE
  (NĐT cá nhân/tổ chức trong nước, NĐT cá nhân/tổ chức nước ngoài), phục vụ báo cáo giao dịch khối
  ngoại. Tài khoản tự doanh (`PROPRIETARY`) luôn là `DOMESTIC` và do 1 broker `RM_VIP` phụ trách.
- **Trưởng phòng / Giám đốc chi nhánh**: `department.head_employee_code` /
  `branch.director_employee_code` - chỉ lưu mã nhân viên (tham chiếu logic sang HR API), dùng để
  tính hoa hồng quản lý (`management_commission_schedule`) và đánh giá phòng ban/chi nhánh.
- **Khách hàng ↔ Môi giới chăm sóc**: SCD Type 2 (`customer_broker_history`) - giữ lịch sử đổi CTV
  theo thời gian, phục vụ tính hoa hồng/AUM đúng theo từng giai đoạn.
- **Mỗi sản phẩm 1 database riêng** (`SSI_Equity`, `SSI_Derivatives`, `SSI_OEF`).
- **HR** chỉ cấp mã nhân viên trong DB; chi tiết (tên, chức danh, cấp bậc, quản lý trực tiếp) lấy qua
  `hr-api/` - tách biệt để sau này thay bằng hệ thống HR thật mà không đổi schema giao dịch.
- Các bảng giao dịch (`equity_trade`, `derivative_trade`, `oef_trade`) và snapshot theo ngày
  (`account_balance_daily`, `position_daily`, `margin_loan_daily`) được **partition theo tháng**
  (RANGE PARTITION FUNCTION/SCHEME) do khối lượng lớn (partition function đã phủ tới 2027-07-01).
- Mã chứng khoán trong `SSI_Equity` là **80 mã hư cấu chia theo 8 nhóm ngành thực tế** (Ngân hàng,
  Bất động sản, Thép-Công nghiệp, Bán lẻ-Tiêu dùng, Công nghệ, Năng lượng-Điện, Chứng khoán,
  Thực phẩm-Đồ uống) với khoảng giá và tỷ trọng sàn HOSE/HNX/UPCOM đặc trưng từng ngành - **không**
  dùng mã/giá của công ty niêm yết thật nào.

### Chạy thử (SQL Server / sqlcmd)

```
sqlcmd -S <server> -d master -i Database/00_create_databases.sql
sqlcmd -S <server> -d master -i Database/Common/run_common.sql
sqlcmd -S <server> -d master -i Database/Equity/run_equity.sql
sqlcmd -S <server> -d master -i Database/Derivatives/run_derivatives.sql
sqlcmd -S <server> -d master -i Database/OEF/run_oef.sql
```
Seed data mẫu (`*_seed_sample_data.sql`) bị comment sẵn trong các script `run_*.sql`, chỉ dùng cho
local/dev testing.

**Dữ liệu quy mô lớn để test báo cáo** (`*_seed_at_scale.sql`, cũng comment sẵn trong `run_*.sql`,
chọn 1 trong 2 với bản seed nhỏ): 300 Môi giới/CTV, 1000 khách hàng (phân bổ lệch - vài môi giới
quản lý sổ lớn, giống thực tế). Giao dịch/tháng, đều nhau qua **tháng 1 đến tháng 6/2027** (6
tháng), gán ngẫu nhiên có trọng số cho khách hàng (KH VIP/Priority kéo nhiều giao dịch hơn KH
Retail, không chia đều tuyệt đối):

| Sản phẩm | Giao dịch/tháng | Tổng 6 tháng |
|---|---|---|
| Cơ sở (Equity) | 1.000.000 | 6.000.000 |
| Phái sinh (Derivatives) | 30.000 | 180.000 |
| CCQ OEF | 10.000 | 60.000 |

Kèm snapshot số dư/vị thế/margin theo ngày. Chạy theo thứ tự: `Common/10_seed_at_scale.sql` trước
(các DB sản phẩm tham chiếu customer/broker từ đây), sau đó `Equity|Derivatives|OEF/07_seed_at_scale.sql`.
Đọc kỹ comment đầu mỗi file - dữ liệu snapshot được sinh độc lập (random walk hợp lý), **không**
đối chiếu chính xác với sổ lệnh giao dịch; và script không idempotent (chạy lại sẽ nhân đôi dữ liệu).

**Dữ liệu mẫu tĩnh, dạng câu INSERT literal** (`Database/StaticSampleData/`) - lựa chọn thứ 3, dùng
khi cần xem/diff/mở trực tiếp file SQL mà không phải chạy generator: cùng logic nghiệp vụ với
`*_seed_at_scale.sql` (phân bổ lệch theo phân khúc KH, hợp đồng phái sinh xoay vòng theo tháng đáo
hạn gần nhất, v.v.) nhưng viết ra thành `INSERT ... VALUES` tĩnh, không có `NEWID()`/random lúc chạy
- chạy lại nhiều lần cho kết quả giống hệt nhau. Quy mô giới hạn ~1000 giao dịch/tháng/sản phẩm
(6000 dòng mỗi bảng giao dịch cho cả 6 tháng) để mỗi file ở mức vài MB, mở được ngay bằng editor
thường, thay vì hàng triệu dòng của bản at-scale. Giá chứng khoán/hợp đồng phái sinh/NAV quỹ đi theo
**random walk thật sự qua từng tháng** (có drift riêng từng mã, hợp đồng phái sinh bám theo đường
VN30 dùng chung) - tránh lỗi random tĩnh quanh 1 giá trị trung bình cố định khiến tháng 1 và tháng 6
giống hệt nhau về mặt thống kê, không có giá trị khai thác cho các báo cáo xu hướng
(`rpt_customer_investment_performance`, dòng tiền quỹ OEF...).

File `Database/StaticSampleData/generate_static_sample.py` là script Python đã dùng để sinh ra các
file `.sql` này (giữ lại để dữ liệu có thể tái tạo/giải thích được, `random.seed(42)` cố định nên
chạy lại luôn ra kết quả giống hệt) - **không** cần chạy lại script này khi setup bình thường, chỉ
cần chạy các file `.sql` đã sinh sẵn theo `run_static_sample.sql`:
```
sqlcmd -S <server> -d master -i Database/StaticSampleData/run_static_sample.sql
```
(yêu cầu đã chạy DDL - `Common/Equity/Derivatives/OEF` `01_schema_init.sql` trở lên - nhưng **chưa**
chạy `*_seed_sample_data.sql`/`*_seed_at_scale.sql` nào).

## 2. HR API (FastAPI)

`hr-api/main.py` - service tĩnh trả về thông tin nhân viên (Môi giới/Trưởng phòng/Giám đốc), gồm
`position_level` và `manager_employee_code` để dựng cây quản lý (dùng cho hoa hồng quản lý).

```
cd hr-api
pip install -r requirements.txt
uvicorn main:app --reload
```
Endpoint chính: `GET /employees`, `GET /employees/{employee_code}`,
`GET /employees/{employee_code}/manager-chain`.

## 3. Pipeline ELT (data-platform/)

### Kiến trúc tổng quan

```
SQL Server (4 DB)                Snowflake                          dbt
┌─────────────┐    Airbyte JDBC  ┌──────────────┐   staging models  ┌───────────┐
│ dimension    │ ───────────────▶│ RAW.<schema>  │──────────────────▶│ STG_*     │
│ tables       │                 │ (typed)       │                    │ (views)   │
└─────────────┘                  └──────────────┘                    └─────┬─────┘
┌─────────────┐  export→Parquet  ┌──────────────┐                          │
│ heavy trade/ │ ───────────────▶│ RAW.<schema>  │  staging (flatten        │
│ snapshot     │  + Snowpipe     │ *_RAW VARIANT │  VARIANT + dedup) ───────┤
│ tables       │  (auto-ingest)  └──────────────┘                          ▼
└─────────────┘                                                    ┌───────────────┐
HR API ─────── Airbyte (low-code connector) ───────────────────────▶│ MARTS          │
                                                                     │ dim / fact /   │
                                                                     │ reports (views)│
                                                                     └───────────────┘
```

Điều phối toàn bộ bởi **Airflow** (`data-platform/airflow/dags/`):
1. `ingest_dimensions` - Airbyte sync các bảng danh mục nhỏ (song song), phát `Dataset` khi xong.
2. `bulk_load_heavy_tables` - export partition ngày sang Parquet, verify Snowpipe đã nạp đủ dòng,
   phát `Dataset` khi xong.
3. `dbt_transform` - **được lên lịch theo cả 2 Dataset trên** (data-aware scheduling), chỉ chạy khi
   dữ liệu ngày hôm đó đã sẵn sàng đầy đủ, không đoán offset giờ chạy.

### Tại sao tách 2 luồng load khác nhau (tối ưu cho dữ liệu lớn)

- **Bảng danh mục/nhỏ** (branch, broker, customer, security, fund, account...) → Airbyte JDBC
  full-refresh, đơn giản, đủ dùng.
- **Bảng giao dịch/snapshot nặng** (equity_trade, derivative_trade, oef_trade,
  account_balance_daily, position_daily, margin_loan_daily) → export theo từng partition ngày ra
  **Parquet**, nạp bằng **Snowpipe/COPY INTO**, nhanh hơn JDBC nhiều lần và **idempotent theo tên
  file** (Snowflake tự chặn nạp trùng file trong 64 ngày → retry an toàn, không tạo dữ liệu trùng).
- Mỗi bảng nặng land vào **1 bảng VARIANT riêng** (`<table>_RAW`, cột `raw_data VARIANT`) thay vì map
  thẳng sang cột kiểu dữ liệu cụ thể - nguồn đổi schema (thêm/đổi tên cột) không làm vỡ pipeline load;
  việc parse/flatten kiểu dữ liệu chỉ làm 1 lần, ở tầng staging của dbt (có version control, có test).
  Việc tạo bảng VARIANT + Snowpipe cho 11 bảng nặng dùng chung 1 stored procedure
  (`RAW.UTIL.CREATE_VARIANT_LANDING`, xem `snowflake/02_variant_landing_util.sql`) thay vì viết tay
  DDL lặp lại 11 lần - tránh sai lệch cấu hình giữa các bảng.
- Airflow verify số dòng đã nạp (so khớp `_RAW` table) trước khi cho phép `dbt_transform` chạy, tránh
  dbt build report trên dữ liệu thiếu/half-loaded của Snowpipe.

### Luồng transform đầy đủ: Stage → Variant → bảng → SCD (2 bảng) → dim/fact → mart

```
Snowflake Stage         RAW.<schema>              STG_<schema>                 MARTS
(Parquet/JDBC)          (Variant/typed)           (dbt staging)                (dbt marts)
┌──────────┐  Snowpipe  ┌───────────────┐  dbt    ┌───────────────┐   dbt run  ┌──────────────┐
│ file/JDBC │──────────▶│ <table>_RAW    │────────▶│ stg_*.sql      │──────────▶│ dim_* (table)│
│           │  COPY INTO│ raw_data       │ flatten │ (view: bảng nhỏ│           │ fact_*(incr) │
└──────────┘            │ VARIANT        │ + dedup │  table: nặng)  │           └──────┬───────┘
                        └───────────────┘         └───────────────┘                  │
                                                                          dbt snapshot│ (SCD Type 2)
                                                                                      ▼
                                                                          ┌─────────────────────┐
                                                                          │ snap_customer_profile│
                                                                          │ (dbt snapshot table) │
                                                                          └──────────┬───────────┘
                                                                                     │ dbt run
                                                                                     ▼
                                                              ┌─────────────┐  ┌──────────────────────┐
                                                              │dim_customer  │  │dim_customer_history   │
                                                              │(bảng CHÍNH,  │  │(bảng HISTORY, SCD2:    │
                                                              │ hiện tại)    │  │ valid_from/valid_to/   │
                                                              └─────────────┘  │ is_current)            │
                                                                                └──────────────────────┘
                                                                                        │
                                                                                        ▼
                                                                          13 report view (marts/reports/)
```

1. **Stage → Variant** (`RAW.<schema>.<table>_RAW`, cột `raw_data VARIANT`): Snowpipe/COPY INTO nạp
   nguyên văn, không map cột - xem mục "Tại sao tách 2 luồng load" ở trên.
2. **Variant → bảng typed** (`stg_*.sql`): flatten `raw_data:col::type` + dedup theo khóa tự nhiên
   (`qualify row_number() ... order by _loaded_at desc`). Model **nhỏ** (branch, broker, customer,
   security,...) giữ `materialized: view` (rẻ, luôn mới nhất). Model **nặng** (3 bảng giao dịch +
   snapshot ngày, 11 model) chuyển sang **`materialized: incremental`** với `unique_key` - tránh
   parse lại VARIANT của hàng triệu dòng cũ mỗi lần dbt chạy, chỉ xử lý phần `_loaded_at` mới.
3. **SCD lưu 2 bảng - 1 bảng chính, 1 bảng history** (áp dụng cho hồ sơ khách hàng hợp nhất):
   - **Bảng chính**: `dim_customer` (`materialized: table`) - chỉ trạng thái hiện tại (segment/risk/
     broker mới nhất), rebuild toàn bộ mỗi lần `dbt run`.
   - **Bảng history**: `dim_customer_history`, dựng trên **dbt snapshot**
     (`snapshots/snap_customer_profile.sql`, strategy `check`) - mỗi lần `dbt snapshot` chạy, so
     sánh `dim_customer` hiện tại với lần chụp trước; nếu segment/risk/broker/is_active đổi thì
     đóng dòng cũ (`valid_to`) và mở dòng mới - **không bao giờ UPDATE/xoá**, nên join theo thời
     điểm quá khứ luôn ổn định dù `dim_customer` bị rebuild toàn bộ mỗi ngày.
   - Thứ tự bắt buộc (xem `dag_dbt_transform.py`): `dbt run` (dim_customer) → **`dbt snapshot`**
     (chụp trạng thái mới vào `snap_customer_profile`) → `dbt run --select dim_customer_history`
     (đọc bản chụp vừa cập nhật) → `dbt test`. Chạy sai thứ tự sẽ khiến `dim_customer_history` đọc
     bản chụp cũ (chậm 1 ngày).
   - Đây là lớp SCD2 **bổ sung ở tầng phân tích**, tách biệt với 3 bảng SCD2 đã có sẵn ở tầng nguồn
     (`customer_broker_history`, `customer_risk_profile`, `customer_segment_history` trong
     `SSI_Common`) - bảng nguồn lưu lịch sử theo TỪNG thuộc tính riêng lẻ (đúng cho ETL/audit),
     còn `dim_customer_history` gộp lại thành 1 "hồ sơ khách hàng đầy đủ tại 1 thời điểm" duy nhất,
     tiện cho báo cáo point-in-time mà không cần join 3 bảng.
4. **dim/fact → data mart → 13 báo cáo**: xem mục 4 bên dưới.

### Chạy thử

```
# Snowflake setup (1 lần)
snowsql -f data-platform/snowflake/00_setup_warehouse_roles.sql
snowsql -f data-platform/snowflake/01_create_databases_schemas.sql
snowsql -f data-platform/snowflake/02_variant_landing_util.sql
snowsql -f data-platform/snowflake/03_bulk_load_equity.sql
snowsql -f data-platform/snowflake/04_bulk_load_derivatives.sql
snowsql -f data-platform/snowflake/05_bulk_load_oef.sql

# Airbyte (Octavia CLI)
cd data-platform/airbyte && octavia apply

# dbt - thu tu quan trong (dim_customer_history phu thuoc dbt snapshot, xem giai thich o tren)
cd data-platform/dbt
cp profiles.yml.example profiles.yml   # dien credentials qua env var, khong hardcode
dbt deps
dbt run --select path:models/staging
dbt test --select path:models/staging
dbt run --select path:models/marts --exclude dim_customer_history
dbt snapshot
dbt run --select dim_customer_history
dbt test --select path:models/marts path:snapshots
```
Chuỗi lệnh trên khớp đúng với `dag_dbt_transform.py` - trong Airflow mỗi bước là 1 task riêng để dễ
thấy lỗi ở đâu, thay vì gộp thành 1 `dbt build` duy nhất.

## 4. Báo cáo phân tích (dbt marts/reports)

13 report view trong `data-platform/dbt/models/marts/reports/`:

| # | Report | Mục đích |
|---|--------|----------|
| 1 | `rpt_broker_commission_revenue` | Hoa hồng & doanh số theo Môi giới/CTV/phòng ban/chi nhánh |
| 2 | `rpt_department_branch_ranking` | Xếp hạng phòng ban/chi nhánh theo doanh số, KH active |
| 3 | `rpt_broker_performance` | Đánh giá CTV/Môi giới: số KH quản lý, doanh số/KH, retention |
| 4 | `rpt_trading_activity_summary` | Hiệu quả giao dịch: turnover, tần suất, giá trị TB/lệnh |
| 5 | `rpt_aum_summary` | AUM theo khách hàng/môi giới/chi nhánh theo thời gian |
| 6 | `rpt_customer_acquisition_funnel` | Khách hàng mới & funnel theo kênh/CTV giới thiệu |
| 7 | `rpt_customer_dormant` | Khách hàng dormant/churn (không giao dịch ≥90 ngày) |
| 8 | `rpt_position_concentration_risk` | Rủi ro tập trung danh mục theo mã CK/khách hàng |
| 9 | `rpt_margin_call_alert` | Cảnh báo margin & tỷ lệ ký quỹ dưới ngưỡng duy trì |
| 10 | `rpt_oef_fund_flow` | Dòng tiền quỹ OEF (net subscription/redemption theo NAV) |
| 11 | `rpt_customer_investment_performance` | Hiệu suất đầu tư KH so với benchmark VN-Index |
| 12 | `rpt_customer_cross_sell` | Khách hàng đang dùng bao nhiêu trong 3 mảng sản phẩm |
| 13 | `rpt_management_override_commission` | Hoa hồng quản lý cho Trưởng phòng/Giám đốc chi nhánh |

## 5. Chạy bằng Docker (local dev)

```
cp .env.example .env   # dien credentials that, khong commit .env
docker compose up -d hr-api airflow-postgres airflow-init airflow-webserver airflow-scheduler
docker compose run --rm dbt run   # ad-hoc dbt, can Snowflake that (khong chay duoc offline)
```
- `docker-compose.yml` build 3 image: `hr-api/Dockerfile`, `data-platform/airflow/Dockerfile`
  (Airflow + Airbyte/Snowflake/dbt providers), `data-platform/dbt/Dockerfile` (dbt standalone).
  Tất cả chạy non-root, không bake secret vào image (đọc qua `.env`).
- SQL Server bị **tắt theo mặc định** (profile `sqlserver`, ảnh lớn + cần EULA) - chỉ bật khi cần:
  `docker compose --profile sqlserver up -d sqlserver`.
- Airbyte **không** vendor trong compose này - dùng installer chính thức của Airbyte
  (`abctl local install`) thay vì tự dựng lại stack nhiều service (temporal, minio,...) của họ.
- Snowflake là dịch vụ cloud, không container hóa - chỉ cần khai `SNOWFLAKE_*` trong `.env`.

## Lưu ý bảo mật & tuân thủ

- `customer.id_number` (CMND/CCCD/MST) **không được đưa vào tầng phân tích** (`stg_common__customer`
  loại bỏ cột này) - dữ liệu định danh cá nhân chỉ nằm trong hệ thống vận hành gốc theo Luật BVDLCN
  91/2025/QH15.
- Toàn bộ credential (SQL Server, Snowflake, Airbyte) lấy qua env/vault, không hardcode trong bất kỳ
  file cấu hình nào ở đây.
- Code do AI sinh ra cần được peer review theo Secure SDLC trước khi merge vào nhánh chính; thay đổi
  lên hệ thống production/trading phải qua Change Management (QĐ 373A/2023).
