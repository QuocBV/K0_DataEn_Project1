# Hướng dẫn cài đặt & khởi chạy toàn bộ hệ thống

Làm theo đúng thứ tự các bước dưới đây - mỗi bước phụ thuộc vào bước trước (SQL Server có dữ liệu
→ Snowflake có schema → Airbyte biết đích đến → Airflow biết gọi Airbyte/dbt ở đâu).

## 0. Yêu cầu trước khi bắt đầu

- Docker + Docker Compose (chạy `hr-api`, Airflow, dbt ad-hoc).
- 1 SQL Server instance - local qua Docker (xem Bước 2) hoặc instance có sẵn của công ty.
- 1 tài khoản Snowflake có quyền tạo WAREHOUSE/DATABASE/ROLE (hoặc nhờ admin Snowflake chạy hộ
  `data-platform/snowflake/00-01_*.sql`).
- [Octavia CLI](https://docs.airbyte.com/using-airbyte/configuring-connector-using-yaml-files)
  (đi kèm khi cài Airbyte qua `abctl local install`).
- `sqlcmd` (đi kèm SQL Server command line tools) hoặc SSMS/Azure Data Studio để chạy script `.sql`.

---

## Bước 1: Tạo file `.env` và điền thông tin

```
cp .env.example .env
```

Mở `.env` và điền từng biến - **không commit file `.env` thật** (đã có trong `.gitignore`/loại trừ
qua `.dockerignore`, nhưng vẫn tự kiểm tra trước khi `git add`):

| Biến | Điền gì | Lấy ở đâu |
|---|---|---|
| `PIP_INDEX_URL` | URL Artifactory nội bộ (đã điền sẵn mẫu) | Đội hạ tầng/CNTT SSI cấp |
| `AIRFLOW_DB_PASSWORD` | Mật khẩu bất kỳ, đủ mạnh (vd tạo bằng `openssl rand -base64 24`) | Bạn tự đặt - đây là mật khẩu cho Postgres nội bộ của Airflow, không phải hệ thống ngoài |
| `AIRFLOW_ADMIN_USER` | Tên đăng nhập Airflow UI (mặc định `admin`) | Bạn tự đặt |
| `AIRFLOW_ADMIN_PASSWORD` | Mật khẩu đăng nhập Airflow UI | Bạn tự đặt, đủ mạnh |
| `SNOWFLAKE_ACCOUNT` | Định danh account Snowflake, vd `ab12345.ap-southeast-1` | Snowflake UI → góc dưới trái → "Account" |
| `SNOWFLAKE_TRANSFORM_USER` | User Snowflake có role `TRANSFORM_ROLE` | Tạo bằng `data-platform/snowflake/00_setup_warehouse_roles.sql` (xem Bước 3) |
| `SNOWFLAKE_TRANSFORM_PASSWORD` | Mật khẩu user trên | Bạn đặt khi tạo user trong Snowflake |
| `MSSQL_HOST` | Host:port SQL Server, vd `localhost,1433` hoặc `sqlserver,1433` nếu chạy qua Docker Compose | Tùy môi trường |
| `MSSQL_EXPORT_USER` / `MSSQL_EXPORT_PASSWORD` | Tài khoản SQL Server **chỉ đọc**, dùng để export Parquet (`scripts/export_partition_to_parquet.py`) | Tạo login riêng trong SQL Server, KHÔNG dùng tài khoản `sa` |
| `MSSQL_SA_PASSWORD` | Mật khẩu `sa` - **chỉ cần nếu chạy SQL Server qua Docker profile `sqlserver`** | Bạn tự đặt, phải thỏa yêu cầu độ phức tạp của SQL Server (≥8 ký tự, đủ 3/4 loại: hoa/thường/số/ký tự đặc biệt) |
| `OPS_ALERT_WEBHOOK_URL` | URL webhook Teams/Slack để nhận cảnh báo khi DAG lỗi (để trống nếu chưa có) | Đội vận hành cấp |
| `HR_API_AUTH_MODE` | `none` (mặc định, dev) / `api_key` / `jwt` | Xem `hr-api/main.py` |
| `HR_API_KEY` / `HR_API_JWT_SECRET` | Chỉ điền nếu đổi `HR_API_AUTH_MODE` khác `none` | Bạn tự đặt |

---

## Bước 2: Khởi tạo 4 database SQL Server

**Nếu chưa có SQL Server sẵn**, bật container local (dùng `MSSQL_SA_PASSWORD` vừa điền ở `.env`):
```
docker compose --profile sqlserver up -d sqlserver
```

Chạy lần lượt (điền `<server>` = `localhost,1433` nếu dùng container trên, `-U sa -P <MSSQL_SA_PASSWORD>` nếu dùng SQL auth):
```
cd Database
sqlcmd -S <server> -U sa -P <mat_khau> -d master -i 00_create_databases.sql
sqlcmd -S <server> -U sa -P <mat_khau> -d master -i Common/run_common.sql
sqlcmd -S <server> -U sa -P <mat_khau> -d master -i Equity/run_equity.sql
sqlcmd -S <server> -U sa -P <mat_khau> -d master -i Derivatives/run_derivatives.sql
sqlcmd -S <server> -U sa -P <mat_khau> -d master -i OEF/run_oef.sql
```

**Muốn có dữ liệu để test báo cáo?** Mở từng file `run_*.sql` vừa chạy, bỏ comment đúng 1 dòng
seed (khuyến nghị `*_seed_at_scale.sql` để có đủ khối lượng, xem README mục 1), rồi chạy lại đúng
file `run_*.sql` đó (không cần chạy lại toàn bộ 5 lệnh trên).

Tạo login riêng cho `MSSQL_EXPORT_USER` (chỉ đọc, dùng cho script export Parquet):
```sql
CREATE LOGIN export_reader WITH PASSWORD = '<MSSQL_EXPORT_PASSWORD>';
CREATE USER export_reader FOR LOGIN export_reader;
-- Lap lai o ca 4 database (SSI_Common, SSI_Equity, SSI_Derivatives, SSI_OEF):
GRANT SELECT ON SCHEMA::raw TO export_reader;
```

---

## Bước 3: Khởi tạo Snowflake

Cần [SnowSQL CLI](https://docs.snowflake.com/en/user-guide/snowsql) hoặc chạy trực tiếp trong
Snowflake Worksheet. Đăng nhập bằng role `ACCOUNTADMIN`:

```
cd data-platform/snowflake
snowsql -a <SNOWFLAKE_ACCOUNT> -u <user_co_quyen_accountadmin> -r ACCOUNTADMIN -f 00_setup_warehouse_roles.sql
```
Mở `00_setup_warehouse_roles.sql`, tạo thêm user thật cho `LOADER_ROLE`/`TRANSFORM_ROLE` (file chỉ
tạo role, không tạo user - vd):
```sql
CREATE USER airbyte_svc PASSWORD = '<mat_khau_manh>' DEFAULT_ROLE = LOADER_ROLE;
GRANT ROLE LOADER_ROLE TO USER airbyte_svc;

CREATE USER dbt_svc PASSWORD = '<chinh_la_SNOWFLAKE_TRANSFORM_PASSWORD>' DEFAULT_ROLE = TRANSFORM_ROLE;
GRANT ROLE TRANSFORM_ROLE TO USER dbt_svc;
```
Tiếp tục:
```
snowsql -a <SNOWFLAKE_ACCOUNT> -u <user> -r ACCOUNTADMIN -f 01_create_databases_schemas.sql
snowsql -a <SNOWFLAKE_ACCOUNT> -u <user> -r TRANSFORM_ROLE -f 02_variant_landing_util.sql
```
**Trước khi chạy 03/04/05** (bulk-load Equity/Derivatives/OEF): cần 1 `STORAGE INTEGRATION` trỏ vào
Azure Blob container - việc này làm 1 lần bởi `ACCOUNTADMIN`, phụ thuộc hạ tầng cloud thật của công
ty (container name, tenant Azure AD) nên không đóng gói sẵn được ở đây. Xem
[Snowflake docs - Azure storage integration](https://docs.snowflake.com/en/user-guide/data-load-azure-config)
rồi mới chạy:
```
snowsql -a <SNOWFLAKE_ACCOUNT> -u <user> -r TRANSFORM_ROLE -f 03_bulk_load_equity.sql
snowsql -a <SNOWFLAKE_ACCOUNT> -u <user> -r TRANSFORM_ROLE -f 04_bulk_load_derivatives.sql
snowsql -a <SNOWFLAKE_ACCOUNT> -u <user> -r TRANSFORM_ROLE -f 05_bulk_load_oef.sql
```

---

## Bước 4: Cài đặt Airbyte + kết nối (Octavia CLI)

```
# Cai Airbyte (1 lan, ngoai docker-compose.yml cua repo nay - xem README)
curl -LsfS https://get.airbyte.com | bash -
abctl local install
```
Sau khi cài xong, Airbyte UI chạy ở `http://localhost:8000` (mặc định) - đăng nhập lần đầu để lấy
user/pass hiển thị trên terminal khi `abctl local install` chạy xong.

```
cd data-platform/airbyte
octavia init
```
Octavia cần các biến môi trường sau (đặt trong `.env` của thư mục `data-platform/airbyte/` theo
[docs Octavia](https://docs.airbyte.com/using-airbyte/configuring-connector-using-yaml-files)):
```
SNOWFLAKE_LOADER_USER=airbyte_svc
SNOWFLAKE_LOADER_PASSWORD=<mat_khau_dat_o_Buoc_3>
MSSQL_HOST=<giong_.env_goc>
MSSQL_AIRBYTE_READER_USER=<tao_rieng_1_login_chi_doc_khac_MSSQL_EXPORT_USER>
MSSQL_AIRBYTE_READER_PASSWORD=<mat_khau>
HR_API_BASE_URL=http://localhost:8000    # doi thanh http://hr-api:8000 neu Airbyte chay trong cung Docker network
HR_API_KEY=<neu_HR_API_AUTH_MODE=api_key>
```
Áp dụng toàn bộ source/destination/connection:
```
octavia apply
```
**Ghi lại UUID của từng connection** mà Octavia in ra sau khi `apply` xong (hoặc xem trong Airbyte
UI → Connections) - Airflow cần map `resource_name` (vd `mssql_common_to_snowflake`) sang UUID thật
này ở Bước 5.

---

## Bước 5: Khởi chạy Docker Compose (hr-api + Airflow + dbt)

```
docker compose up -d hr-api airflow-postgres airflow-init airflow-webserver airflow-scheduler
```
Đợi ~1 phút cho `airflow-init` migrate DB + tạo user admin, sau đó mở `http://localhost:8080`,
đăng nhập bằng `AIRFLOW_ADMIN_USER`/`AIRFLOW_ADMIN_PASSWORD` đã điền ở `.env`.

**2 việc BẮT BUỘC phải làm thủ công trong Airflow UI** (không nằm trong `.env`, vì đây là cấu hình
riêng của Airflow, không phải secret của hệ thống ngoài):

1. **Admin → Connections → +** : tạo connection `airbyte_default` (Connection Type: `Airbyte`),
   Host = `host.docker.internal` (hoặc IP thật của máy chạy Airbyte), Port = `8000`.
2. **Admin → Connections → +** : tạo connection `snowflake_default` (Connection Type: `Snowflake`),
   điền Account/User/Password/Warehouse giống `SNOWFLAKE_*` ở `.env` + Role = `TRANSFORM_ROLE`.
3. **Admin → Variables → +** : tạo Variable tên `airbyte_connection_ids`, kiểu JSON, giá trị là map
   `resource_name → UUID` lấy từ Bước 4:
   ```json
   {
     "mssql_common_to_snowflake": "<uuid>",
     "mssql_equity_to_snowflake": "<uuid>",
     "mssql_derivatives_to_snowflake": "<uuid>",
     "mssql_oef_to_snowflake": "<uuid>",
     "hr_api_to_snowflake": "<uuid>"
   }
   ```

Bật 3 DAG trong Airflow UI (`ingest_dimensions`, `bulk_load_heavy_tables`, `dbt_transform`) bằng nút
toggle - mặc định DAG mới tạo ở trạng thái tắt (paused).

---

## Bước 6: Chạy dbt lần đầu bằng tay (không qua Airflow, để kiểm tra nhanh)

```
cd data-platform/dbt
cp profiles.yml.example profiles.yml
# profiles.yml doc bien moi truong qua env_var() - export truoc khi chay:
export SNOWFLAKE_ACCOUNT=...
export SNOWFLAKE_TRANSFORM_USER=...
export SNOWFLAKE_TRANSFORM_PASSWORD=...

dbt deps
dbt run --select path:models/staging
dbt test --select path:models/staging
dbt run --select path:models/marts --exclude dim_customer_history
dbt snapshot
dbt run --select dim_customer_history
dbt test --select path:models/marts path:snapshots
```
(Đúng thứ tự này bắt buộc - xem README mục "Luồng transform đầy đủ" để hiểu vì sao.)

---

## Bước 7: Kiểm tra toàn hệ thống chạy đúng

1. Airflow UI → chạy tay (Trigger DAG) `ingest_dimensions` → phải chuyển xanh (success).
2. Chạy tay `bulk_load_heavy_tables` → cần đã export Parquet + Snowpipe nạp xong (có thể mất vài
   phút do Snowpipe auto-ingest không tức thời).
3. `dbt_transform` sẽ **tự động** chạy sau khi cả 2 DAG trên xong (data-aware scheduling qua
   Dataset) - không cần trigger tay.
4. Vào Snowflake, kiểm tra `ANALYTICS.MARTS.RPT_BROKER_COMMISSION_REVENUE` (hoặc bất kỳ report nào
   trong 13 báo cáo) đã có dữ liệu.

---

## Xử lý sự cố thường gặp

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| `airflow-init` thoát ngay, container "Exited (1)" | `AIRFLOW_DB_PASSWORD` để trống hoặc `airflow-postgres` chưa healthy - kiểm tra `docker compose logs airflow-postgres` |
| DAG `ingest_dimensions` lỗi "Connection airbyte_default not found" | Chưa tạo Connection ở Bước 5 mục 1 |
| DAG lỗi `KeyError` khi đọc `var.json.airbyte_connection_ids` | Chưa tạo Variable ở Bước 5 mục 3, hoặc thiếu 1 trong 5 resource_name |
| `bulk_load_heavy_tables` báo "0 rows for <date>" | Snowpipe chưa kịp nạp (đợi thêm) hoặc chưa setup Storage Integration (Bước 3) |
| dbt báo lỗi thiếu bảng `RAW.<SCHEMA>.<TABLE>` | Chưa chạy Airbyte `octavia apply` (Bước 4) hoặc DAG `ingest_dimensions` chưa chạy lần nào |
| Seed script SQL Server báo lỗi ngay dòng đầu | Chưa chạy `Common/10_seed_at_scale.sql` trước khi chạy seed của Equity/Derivatives/OEF (xem thông báo lỗi cụ thể - đã có RAISERROR rõ ràng) |

## Xem thêm
- `README.md` - kiến trúc tổng quan, giải thích từng thành phần.
- `Database/DATA_MODEL.md` - sơ đồ quan hệ dữ liệu chi tiết.
