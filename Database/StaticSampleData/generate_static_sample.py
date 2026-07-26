"""One-time generator that PRODUCES static .sql files full of literal INSERT...VALUES statements
(no NEWID()/random at runtime, no generator logic in the output) for Database/StaticSampleData/.
Run once; the .sql files it writes are the actual deliverable - this script itself is kept
alongside them only so the data is reproducible/explainable, it is not meant to be re-run as part
of normal DB setup (see Database/*/07_seed_at_scale.sql for that).

Scale: ~1000 rows/month for the big trade tables (6000 total per trade table across Jan-Jun 2027),
full natural counts for dimension tables (branch/department/broker/customer/security/contract/
fund/account, all already <=1000), and a 1-representative-date-per-month sample (not every day)
for balance/position/margin/price-history tables - chosen so every generated .sql file stays in
the low single-digit MB range and opens instantly in a normal editor, while still being large
enough to exercise every report.
"""
import random
from datetime import date, timedelta

random.seed(42)

OUT_DIR = "d:/Project/Project_De/Database/StaticSampleData"

FIRST_NAMES = ["Van An", "Thi Bich", "Minh Chau", "Quoc Dung", "Thi Ha", "Hoang Khoa", "Thi Lan",
               "Van Minh", "Thi Ngoc", "Duc Phong", "Thi Quyen", "Van Son", "Thi Thao", "Anh Tuan",
               "Thi Van", "Xuan Y", "Gia Bao", "Ngoc Diep", "Huu Loc", "Kim Ngan"]
LAST_NAMES = ["Nguyen", "Tran", "Le", "Pham", "Hoang", "Huynh", "Phan", "Vu", "Vo", "Dang", "Bui",
              "Do", "Ho", "Ngo", "Duong"]


def full_name():
    return f"{random.choice(LAST_NAMES)} {random.choice(FIRST_NAMES)}"


def sql_str(s):
    return "'" + str(s).replace("'", "''") + "'"


def n_str(s):
    return "N'" + str(s).replace("'", "''") + "'"


def sql_val(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, date):
        return sql_str(v.isoformat())
    if isinstance(v, str) and v.startswith("\x00N"):
        return n_str(v[2:])
    return sql_str(v)


def nv(s):
    """Mark a string as NVARCHAR so sql_val() emits it with an N'' prefix."""
    return "\x00N" + s


def emit_inserts(f, table, columns, rows, chunk_size=500):
    if not rows:
        return
    for start in range(0, len(rows), chunk_size):
        chunk = rows[start:start + chunk_size]
        f.write(f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n")
        lines = ["    (" + ", ".join(sql_val(v) for v in row) + ")" for row in chunk]
        f.write(",\n".join(lines))
        f.write(";\n\n")


def trading_days_in_month(year, month):
    d = date(year, month, 1)
    days = []
    while d.month == month:
        if d.weekday() < 5:
            days.append(d)
        d += timedelta(days=1)
    return days


MONTHS_2027 = list(range(1, 7))
SNAPSHOT_DATES = [date(2027, m, 15) for m in MONTHS_2027]

# =====================================================================================
# 1. SSI_Common
# =====================================================================================
branches = [
    ("CN01", nv("Chi nhanh Ha Noi"), "NV9001"),
    ("CN02", nv("Chi nhanh TP.HCM"), "NV9002"),
    ("CN03", nv("Chi nhanh Da Nang"), "NV9003"),
    ("CN04", nv("Chi nhanh Hai Phong"), None),
    ("CN05", nv("Chi nhanh Can Tho"), None),
]

departments = []
for i in range(1, 16):
    branch_id = ((i - 1) % 5) + 1
    head = f"NV9{i:02d}" if i % 3 == 0 else None
    departments.append((f"PB{i:03d}", nv(f"Phong Moi Gioi {i}"), branch_id, "BROKERAGE", head))

BROKER_SUBTYPES_BROKER = ["STANDARD"] * 70 + ["SENIOR"] * 20 + ["TEAM_LEAD"] * 7 + ["RM_VIP"] * 3
BROKER_SUBTYPES_CTV = ["REFERRAL_INDIVIDUAL"] * 60 + ["REFERRAL_AFFILIATE"] * 30 + ["REFERRAL_INSTITUTIONAL"] * 10

brokers = []
broker_codes_by_subtype = {}
for i in range(1, 301):
    broker_code = f"MG{i:04d}"
    is_broker = (i % 10) < 7
    broker_type = "BROKER" if is_broker else "COLLABORATOR"
    subtype = random.choice(BROKER_SUBTYPES_BROKER if is_broker else BROKER_SUBTYPES_CTV)
    employee_code = f"NV{2000 + i:04d}" if is_broker else None
    id_number = f"0900{i:08d}"
    phone = f"09{random.randint(0, 9999999):07d}"
    email = f"broker{i}@ssi.com.vn"
    start_date = date(2027, 1, 1) - timedelta(days=random.randint(0, 2000))
    dept_id = ((i - 1) % 15) + 1
    brokers.append((broker_code, nv(full_name()), broker_type, subtype, dept_id, employee_code,
                     id_number, phone, email, start_date))
    broker_codes_by_subtype.setdefault(subtype, []).append(broker_code)

if not broker_codes_by_subtype.get("RM_VIP"):
    bc, name, _, _, dept_id, emp, idn, ph, em, sd = brokers[0]
    brokers[0] = (bc, name, "BROKER", "RM_VIP", dept_id, emp, idn, ph, em, sd)
    broker_codes_by_subtype.setdefault("RM_VIP", []).append(bc)

rm_vip_broker = broker_codes_by_subtype["RM_VIP"][0]
non_rm_vip_brokers = [b[0] for b in brokers if b[3] != "RM_VIP"]

customers = []
for i in range(1, 999):
    customer_code = f"KH{i:05d}"
    is_org = (i % 10) == 0
    name = (nv("Cong ty TNHH " + full_name())) if is_org else nv(full_name())
    ctype = "ORGANIZATION" if is_org else "INDIVIDUAL"
    residency = "FOREIGN" if random.randint(0, 99) < 8 else "DOMESTIC"
    phone = f"09{random.randint(0, 9999999):07d}"
    email = f"customer{i}@example.com"
    open_date = date(2027, 1, 1) - timedelta(days=random.randint(0, 1460))
    customers.append((customer_code, name, ctype, residency, phone, email, open_date))

proprietary_customers = [
    ("TD0001", nv("SSI - Tai khoan tu doanh 1"), "PROPRIETARY", "DOMESTIC", None, None, date(2015, 1, 1)),
    ("TD0002", nv("SSI - Tai khoan tu doanh 2"), "PROPRIETARY", "DOMESTIC", None, None, date(2015, 1, 1)),
]
all_customers = customers + proprietary_customers

weights = {bc: random.randint(1, 15) for bc in non_rm_vip_brokers}
weighted_pool = []
for bc, w in weights.items():
    weighted_pool.extend([bc] * w)

customer_broker_history = []
customer_current_broker = {}
for c in customers:
    customer_code = c[0]
    broker_code = random.choice(weighted_pool)
    valid_from = date(2027, 1, 1) - timedelta(days=random.randint(0, 1000))
    customer_broker_history.append((customer_code, broker_code, valid_from, None, 1))
    customer_current_broker[customer_code] = broker_code
for cc, *_ in proprietary_customers:
    customer_broker_history.append((cc, rm_vip_broker, date(2015, 1, 1), None, 1))
    customer_current_broker[cc] = rm_vip_broker

customer_risk_profile = []
for c in all_customers:
    customer_code, _, _, _, _, _, open_date_ = c
    roll = random.randint(0, 99)
    classification = "PROFESSIONAL" if roll < 5 else "NON_PROFESSIONAL"
    risk = "LOW" if roll < 50 else ("MEDIUM" if roll < 85 else "HIGH")
    customer_risk_profile.append((customer_code, classification, risk, open_date_, None, 1))

customer_segment_history = []
for c in all_customers:
    customer_code, _, ctype, _, _, _, open_date_ = c
    if ctype == "PROPRIETARY":
        segment = "VIP"
    else:
        roll = random.randint(0, 99)
        segment = "RETAIL" if roll < 80 else ("PRIORITY" if roll < 95 else "VIP")
    customer_segment_history.append((customer_code, segment, open_date_, None, 1))

customer_acquisition = []
for c in customers:
    customer_code, _, _, _, _, _, open_date_ = c
    roll = random.randint(0, 99)
    channel = "BRANCH" if roll < 40 else ("ONLINE" if roll < 75 else ("REFERRAL" if roll < 95 else "EVENT"))
    referral_broker = customer_current_broker[customer_code] if channel == "REFERRAL" else None
    customer_acquisition.append((customer_code, channel, referral_broker, open_date_, None))
for cc, *_ in proprietary_customers:
    customer_acquisition.append((cc, "BRANCH", None, date(2015, 1, 1), None))

fee_schedule = [
    ("EQUITY", None, 0.0015, 0.30, date(2022, 1, 1), None, 1),
    ("DERIVATIVES", None, 0.0002, 0.25, date(2022, 1, 1), None, 1),
    ("OEF", None, 0.0000, 0.50, date(2022, 1, 1), None, 1),
]
management_commission_schedule = [
    ("HEAD_OF_DEPARTMENT", 0.05, date(2022, 1, 1), None, 1),
    ("BRANCH_DIRECTOR", 0.03, date(2022, 1, 1), None, 1),
]
market_index_price = []
vn30_by_date = {}
vnindex_base, vn30_base = 1280.0, 1330.0
for d in SNAPSHOT_DATES:
    vnindex_base *= 1 + random.uniform(-0.02, 0.02)
    vn30_base *= 1 + random.uniform(-0.02, 0.02)
    market_index_price.append((d, "VNINDEX", round(vnindex_base, 2), round(random.uniform(-1, 1), 2), None))
    market_index_price.append((d, "VN30", round(vn30_base, 2), round(random.uniform(-1, 1), 2), None))
    vn30_by_date[d] = vn30_base

with open(f"{OUT_DIR}/01_common_sample.sql", "w", encoding="utf-8") as f:
    f.write("USE SSI_Common;\nGO\n\n")
    f.write("-- Static literal sample data (~1000 rows/table cap on the big tables) - see\n")
    f.write("-- Database/StaticSampleData/generate_static_sample.py for how this file was produced.\n")
    f.write("-- Alternative to 09_seed_sample_data.sql / 10_seed_at_scale.sql - run exactly ONE of\n")
    f.write("-- the three against a fresh database.\n\n")
    emit_inserts(f, "raw.branch", ["branch_code", "branch_name", "director_employee_code"], branches)
    emit_inserts(f, "raw.department", ["department_code", "department_name", "branch_id", "department_type", "head_employee_code"], departments)
    emit_inserts(f, "raw.broker", ["broker_code", "broker_name", "broker_type", "broker_subtype", "department_id", "employee_code", "id_number", "phone", "email", "start_date"], brokers)
    emit_inserts(f, "raw.customer", ["customer_code", "customer_name", "customer_type", "residency", "phone", "email", "open_date"], all_customers)
    emit_inserts(f, "raw.customer_broker_history", ["customer_code", "broker_code", "valid_from", "valid_to", "is_current"], customer_broker_history)
    emit_inserts(f, "raw.customer_risk_profile", ["customer_code", "investor_classification", "risk_level", "valid_from", "valid_to", "is_current"], customer_risk_profile)
    emit_inserts(f, "raw.customer_segment_history", ["customer_code", "segment", "valid_from", "valid_to", "is_current"], customer_segment_history)
    emit_inserts(f, "raw.customer_acquisition", ["customer_code", "acquisition_channel", "referral_broker_code", "acquisition_date", "campaign_code"], customer_acquisition)
    emit_inserts(f, "raw.fee_schedule", ["product_type", "broker_tier", "fee_rate", "commission_rate", "effective_from", "effective_to", "is_current"], fee_schedule)
    emit_inserts(f, "raw.management_commission_schedule", ["management_level", "commission_rate", "effective_from", "effective_to", "is_current"], management_commission_schedule)
    emit_inserts(f, "raw.market_index_price", ["price_date", "index_code", "close_value", "change_percent", "volume"], market_index_price)

print(f"Common: branches={len(branches)} departments={len(departments)} brokers={len(brokers)} "
      f"customers={len(all_customers)} cbh={len(customer_broker_history)} risk={len(customer_risk_profile)} "
      f"segment={len(customer_segment_history)} acquisition={len(customer_acquisition)}")

# =====================================================================================
# 2. SSI_Equity
# =====================================================================================
SECTOR_DEF = [
    ("Ngan hang", "B", "HOSE", 20, 45),
    ("Bat dong san", "D", "HOSE", 25, 90),
    ("Thep - Cong nghiep", "K", "HOSE", 15, 40),
    ("Ban le - Tieu dung", "R", "HOSE", 35, 80),
    ("Cong nghe", "T", "HOSE", 45, 120),
    ("Nang luong - Dien", "G", "UPCOM", 15, 35),
    ("Chung khoan", "X", "HNX", 10, 30),
    ("Thuc pham - Do uong", "F", "UPCOM", 20, 60),
]

securities = []  # (security_id, symbol, name, exchange, sector, security_type, listing_date, base_price)
sec_id = 0
for sector_name, prefix, exch, pmin, pmax in SECTOR_DEF:
    for seq in range(1, 11):
        sec_id += 1
        symbol = prefix + "A" + chr(64 + seq)
        exchange = exch if seq <= 6 else ("HNX" if exch == "HOSE" else "UPCOM")
        listing_date = date(2027, 1, 1) - timedelta(days=random.randint(0, 3650))
        base_price = round(pmin + (sec_id * 37) % max(pmax - pmin, 1), 2)
        securities.append((sec_id, symbol, nv(f"CTCP {sector_name} {seq}"), exchange, nv(sector_name), "STOCK", listing_date, base_price))

daily_price = []
for sid, symbol, name, exch, sector, stype, listing_date, base_price in securities:
    # Random walk per security (own drift bias + monthly noise), not iid noise around a fixed
    # mean - otherwise month 1 and month 6 are statistically identical and trend-based reports
    # (rpt_customer_investment_performance, etc.) have nothing real to show.
    drift = random.uniform(-0.025, 0.03)
    level = base_price
    for d in SNAPSHOT_DATES:
        reference_price = level
        level = round(level * (1 + drift + random.uniform(-0.03, 0.03)), 2)
        daily_price.append((d, sid, level, reference_price, round(reference_price * 1.07, 2), round(reference_price * 0.93, 2), random.randint(1000, 2000000)))

equity_customers = random.sample(customers, 800)
equity_accounts = []  # (account_id, account_no, customer_code, broker_code, open_date)
for idx, c in enumerate(equity_customers, start=1):
    customer_code = c[0]
    equity_accounts.append((idx, f"0001{idx:06d}", customer_code, customer_current_broker[customer_code], c[6]))

sec_weight_pool = []
for sid, *_rest in securities:
    w = 20 if ((sid - 1) % 10) < 6 else 1  # first 6 of every 10-ticker sector block = blue chip
    sec_weight_pool.extend([sid] * w)

seg_by_customer = {row[0]: row[1] for row in customer_segment_history}


def account_weight_pool(accounts, weight_map):
    pool = []
    for acc in accounts:
        customer_code = acc[2]
        seg = seg_by_customer.get(customer_code, "RETAIL")
        pool.extend([acc[0]] * weight_map.get(seg, 1))
    return pool


equity_acct_pool = account_weight_pool(equity_accounts, {"VIP": 8, "PRIORITY": 3, "RETAIL": 1})
equity_acct_by_id = {a[0]: a for a in equity_accounts}
sec_by_id = {s[0]: s for s in securities}
price_by_sec_date = {(sid, d): price for (d, sid, price, *_r) in daily_price}

equity_trade = []
trade_counter = 0
for m in MONTHS_2027:
    tdays = trading_days_in_month(2027, m)
    for _ in range(1000):
        trade_counter += 1
        trade_date = random.choice(tdays)
        acct_id = random.choice(equity_acct_pool)
        acct = equity_acct_by_id[acct_id]
        sid = random.choice(sec_weight_pool)
        sec = sec_by_id[sid]
        side = random.choice(["BUY", "SELL"])
        qty = random.randint(1, 50) * 100
        month_price = price_by_sec_date.get((sid, SNAPSHOT_DATES[m - 1]), sec[7])
        price = round(month_price * (1 + random.uniform(-0.01, 0.01)), 2)
        amount = round(qty * price, 2)
        fee = round(amount * 0.0015, 2)
        tax = round(amount * 0.001, 2) if side == "SELL" else 0
        trade_dt = f"{trade_date.isoformat()}T{random.randint(9,14):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"
        source_trade_id = f"EQ-{m:02d}2027-{trade_counter:07d}"
        equity_trade.append((
            trade_date, trade_dt, source_trade_id, acct[1], acct[2], acct[3], sid, sec[3], side,
            "LO", qty, price, amount, fee, tax, trade_date + timedelta(days=2),
            f"ORD-{m:02d}2027-{trade_counter}", "CORE_TRADING",
        ))

equity_balance = []
equity_wealth = {a[0]: (random.uniform(5_000_000, 500_000_000), random.uniform(10_000_000, 1_000_000_000)) for a in equity_accounts}
for d in SNAPSHOT_DATES:
    for acc in equity_accounts:
        base_cash, base_port = equity_wealth[acc[0]]
        cash = round(base_cash * random.uniform(0.9, 1.1), 2)
        port = round(base_port * random.uniform(0.9, 1.1), 2)
        equity_balance.append((d, acc[0], cash, port, round(cash + port, 2)))

equity_position_accounts = equity_accounts[:150]
equity_holdings = {}
for acc in equity_position_accounts:
    n_hold = random.randint(3, 8)
    equity_holdings[acc[0]] = random.sample([s[0] for s in securities], n_hold)

equity_position = []
for d in SNAPSHOT_DATES:
    for acc in equity_position_accounts:
        for sid in equity_holdings[acc[0]]:
            sec = sec_by_id[sid]
            qty = random.randint(1, 50) * 100
            cost = round(sec[7] * random.uniform(0.95, 1.05), 4)
            mv = round(qty * price_by_sec_date.get((sid, d), sec[7]), 2)
            equity_position.append((d, acc[0], sid, qty, cost, mv))

equity_margin_accounts = random.sample(equity_accounts, int(len(equity_accounts) * 0.3))
equity_margin_base = {a[0]: random.uniform(20_000_000, 500_000_000) for a in equity_margin_accounts}
equity_margin = []
for d in SNAPSHOT_DATES:
    for acc in equity_margin_accounts:
        balance = round(equity_margin_base[acc[0]] * random.uniform(0.85, 1.15), 2)
        ratio = round(random.uniform(0.10, 0.50), 4)
        equity_margin.append((d, acc[0], balance, ratio, 0.15, 1 if ratio < 0.15 else 0))

with open(f"{OUT_DIR}/02_equity_sample.sql", "w", encoding="utf-8") as f:
    f.write("USE SSI_Equity;\nGO\n\n")
    f.write("-- Static literal sample data - see generate_static_sample.py. Requires\n")
    f.write("-- StaticSampleData/01_common_sample.sql to have been run first (customer_code/\n")
    f.write("-- broker_code are cross-database logical references, no DB-level FK).\n")
    f.write("-- Alternative to Database/Equity/06_seed_sample_data.sql / 07_seed_at_scale.sql.\n\n")
    emit_inserts(f, "raw.security", ["symbol", "security_name", "exchange", "sector", "security_type", "listing_date"],
                 [(s[1], s[2], s[3], s[4], s[5], s[6]) for s in securities])
    emit_inserts(f, "raw.daily_price", ["price_date", "security_id", "close_price", "reference_price", "ceiling_price", "floor_price", "volume"], daily_price)
    emit_inserts(f, "raw.account", ["account_no", "customer_code", "broker_code", "open_date"],
                 [(a[1], a[2], a[3], a[4]) for a in equity_accounts])
    emit_inserts(f, "raw.equity_trade", [
        "trade_date", "trade_datetime", "source_trade_id", "account_no", "customer_code", "broker_code",
        "security_id", "market", "side", "order_type", "quantity", "price", "amount", "fee_amount",
        "tax_amount", "settlement_date", "order_id", "source_system"], equity_trade)
    emit_inserts(f, "raw.account_balance_daily", ["balance_date", "account_id", "cash_balance", "portfolio_value", "total_asset_value"], equity_balance)
    emit_inserts(f, "raw.position_daily", ["position_date", "account_id", "security_id", "quantity", "avg_cost_price", "market_value"], equity_position)
    emit_inserts(f, "raw.margin_loan_daily", ["loan_date", "account_id", "margin_loan_balance", "margin_ratio", "maintenance_margin_ratio", "call_margin_flag"], equity_margin)

print(f"Equity: securities={len(securities)} daily_price={len(daily_price)} accounts={len(equity_accounts)} "
      f"trades={len(equity_trade)} balance={len(equity_balance)} position={len(equity_position)} margin={len(equity_margin)}")

# =====================================================================================
# 3. SSI_Derivatives
# =====================================================================================
contracts = []  # (contract_id, contract_code, underlying_symbol, contract_type, multiplier, listing_date, maturity_date)
for n in range(10):
    month = date(2026, 11, 1)
    for _ in range(n):
        month = date(month.year + (1 if month.month == 12 else 0), 1 if month.month == 12 else month.month + 1, 1)
    maturity = date(month.year + (1 if month.month == 12 else 0), 1 if month.month == 12 else month.month + 1, 1) - timedelta(days=1)
    listing = date(month.year, month.month, 1)
    for _ in range(3):
        listing = date(listing.year - (1 if listing.month == 1 else 0), 12 if listing.month == 1 else listing.month - 1, 1)
    contracts.append((n + 1, f"VN30F{month.strftime('%y%m')}", "VN30", "INDEX_FUTURES", 100000, listing, maturity))

daily_settlement_price = []
for cid, code, underlying, ctype, mult, listing, maturity in contracts:
    # All VN30F contracts track the same underlying VN30 path (see vn30_by_date above) plus a
    # small per-contract basis - correlated realistic movement instead of iid noise around a
    # fixed 1300, so settlement price actually trends month over month like a real futures curve.
    basis = random.uniform(-5, 5)
    for d in SNAPSHOT_DATES:
        if listing <= d <= maturity:
            price = round(vn30_by_date[d] + basis + random.uniform(-3, 3), 2)
            daily_settlement_price.append((d, cid, price, random.randint(5000, 50000), random.randint(500, 50500)))

deriv_customers = random.sample(customers, 250)
deriv_accounts = []
for idx, c in enumerate(deriv_customers, start=1):
    customer_code = c[0]
    deriv_accounts.append((idx, f"0002{idx:06d}", customer_code, customer_current_broker[customer_code], c[6]))

deriv_acct_pool = account_weight_pool(deriv_accounts, {"VIP": 10, "PRIORITY": 3, "RETAIL": 1})
deriv_acct_by_id = {a[0]: a for a in deriv_accounts}
contract_by_id = {c[0]: c for c in contracts}
settlement_by_contract_date = {(cid, d): p for (d, cid, p, *_r) in daily_settlement_price}

derivative_trade = []
trade_counter = 0
for m in MONTHS_2027:
    tdays = trading_days_in_month(2027, m)
    month_start = date(2027, m, 1)
    active_contracts = sorted([c for c in contracts if c[6] >= month_start], key=lambda c: c[6])
    weight_pool = []
    for rank, c in enumerate(active_contracts):
        w = 15 if rank == 0 else (4 if rank == 1 else 1)
        weight_pool.extend([c[0]] * w)
    for _ in range(1000):
        trade_counter += 1
        trade_date = random.choice(tdays)
        acct_id = random.choice(deriv_acct_pool)
        acct = deriv_acct_by_id[acct_id]
        cid = random.choice(weight_pool)
        contract = contract_by_id[cid]
        side = random.choice(["LONG", "SHORT"])
        action = random.choice(["OPEN", "OPEN", "OPEN", "CLOSE", "CLOSE", "CLOSE"])  # ~60/40
        qty = random.randint(1, 20)
        settle = settlement_by_contract_date.get((cid, SNAPSHOT_DATES[m - 1]), 1300)
        price = round(settle * (1 + random.uniform(-0.005, 0.005)), 2)
        multiplier = contract[4]
        amount = round(qty * price * multiplier, 2)
        margin = round(amount * 0.15, 2)
        fee = round(amount * 0.0002, 2)
        trade_dt = f"{trade_date.isoformat()}T{random.randint(9,14):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"
        source_trade_id = f"DR-{m:02d}2027-{trade_counter:07d}"
        derivative_trade.append((
            trade_date, trade_dt, source_trade_id, acct[1], acct[2], acct[3], cid, side, action,
            qty, price, amount, margin, fee, trade_date + timedelta(days=2),
            f"ORD-{m:02d}2027-{trade_counter}", "DERIVATIVES",
        ))

deriv_balance = []
deriv_wealth = {a[0]: (random.uniform(20_000_000, 500_000_000), random.uniform(10_000_000, 300_000_000)) for a in deriv_accounts}
for d in SNAPSHOT_DATES:
    for acc in deriv_accounts:
        base_cash, base_port = deriv_wealth[acc[0]]
        cash = round(base_cash * random.uniform(0.9, 1.1), 2)
        port = round(base_port * random.uniform(0.9, 1.1), 2)
        deriv_balance.append((d, acc[0], cash, port, round(cash + port, 2)))

# Holdings restricted to contracts that haven't matured by the end of the snapshot window
valid_holding_contracts = [c[0] for c in contracts if c[6] >= SNAPSHOT_DATES[-1]]
deriv_position_accounts = deriv_accounts[:100]
deriv_holdings = {}
for acc in deriv_position_accounts:
    n_hold = min(random.randint(1, 3), len(valid_holding_contracts))
    deriv_holdings[acc[0]] = random.sample(valid_holding_contracts, n_hold)

deriv_position = []
for d in SNAPSHOT_DATES:
    for acc in deriv_position_accounts:
        for cid in deriv_holdings[acc[0]]:
            contract = contract_by_id[cid]
            side = random.choice(["LONG", "SHORT"])
            qty = random.randint(1, 20)
            cost = 1300.0
            mv = round(qty * settlement_by_contract_date.get((cid, d), cost) * contract[4], 2)
            deriv_position.append((d, acc[0], cid, side, qty, cost, mv))

deriv_margin = []
for d in SNAPSHOT_DATES:
    for acc in deriv_accounts:  # 100% of derivatives accounts are margin-based
        base_cash, base_port = deriv_wealth[acc[0]]
        balance = round(base_port * 0.15 * random.uniform(0.85, 1.15), 2)
        ratio = round(random.uniform(0.10, 0.50), 4)
        deriv_margin.append((d, acc[0], balance, ratio, 0.15, 1 if ratio < 0.15 else 0))

with open(f"{OUT_DIR}/03_derivatives_sample.sql", "w", encoding="utf-8") as f:
    f.write("USE SSI_Derivatives;\nGO\n\n")
    f.write("-- Static literal sample data - see generate_static_sample.py. Requires\n")
    f.write("-- StaticSampleData/01_common_sample.sql to have been run first.\n")
    f.write("-- Alternative to Database/Derivatives/06_seed_sample_data.sql / 07_seed_at_scale.sql.\n\n")
    emit_inserts(f, "raw.derivative_contract", ["contract_code", "underlying_symbol", "contract_type", "multiplier", "listing_date", "maturity_date"],
                 [(c[1], c[2], c[3], c[4], c[5], c[6]) for c in contracts])
    emit_inserts(f, "raw.daily_settlement_price", ["price_date", "contract_id", "settlement_price", "open_interest", "volume"], daily_settlement_price)
    emit_inserts(f, "raw.account", ["account_no", "customer_code", "broker_code", "open_date"],
                 [(a[1], a[2], a[3], a[4]) for a in deriv_accounts])
    emit_inserts(f, "raw.derivative_trade", [
        "trade_date", "trade_datetime", "source_trade_id", "account_no", "customer_code", "broker_code",
        "contract_id", "position_side", "order_action", "quantity", "price", "amount", "margin_amount",
        "fee_amount", "settlement_date", "order_id", "source_system"], derivative_trade)
    emit_inserts(f, "raw.account_balance_daily", ["balance_date", "account_id", "cash_balance", "portfolio_value", "total_asset_value"], deriv_balance)
    emit_inserts(f, "raw.position_daily", ["position_date", "account_id", "contract_id", "position_side", "quantity", "avg_cost_price", "market_value"], deriv_position)
    emit_inserts(f, "raw.margin_loan_daily", ["loan_date", "account_id", "margin_loan_balance", "margin_ratio", "maintenance_margin_ratio", "call_margin_flag"], deriv_margin)

print(f"Derivatives: contracts={len(contracts)} settlement_price={len(daily_settlement_price)} accounts={len(deriv_accounts)} "
      f"trades={len(derivative_trade)} balance={len(deriv_balance)} position={len(deriv_position)} margin={len(deriv_margin)}")

# =====================================================================================
# 4. SSI_OEF
# =====================================================================================
FUND_TYPE_NAMES = {"EQUITY_FUND": "Co phieu", "BOND_FUND": "Trai phieu", "BALANCED": "Can bang"}
funds = []  # (fund_id, fund_code, fund_name, fund_type, fund_manager, inception_date, base_nav)
for n in range(1, 11):
    ftype = "EQUITY_FUND" if n % 10 < 6 else ("BOND_FUND" if n % 10 < 9 else "BALANCED")
    inception = date(2027, 1, 1) - timedelta(days=random.randint(0, 3650))
    base_nav = 10000 + (n * 977) % 20000
    funds.append((n, f"SSIF{n:02d}", nv(f"Quy {FUND_TYPE_NAMES[ftype]} {n}"), ftype, nv("SSIAM"), inception, base_nav))

fund_nav_history = []
for fid, code, name, ftype, manager, inception, base_nav in funds:
    # Random walk (drift + noise compounding), not iid noise around a fixed base_nav - a fund's
    # NAV genuinely trends over time, it doesn't oscillate around one fixed level for 6 months.
    is_bond = ftype == "BOND_FUND"
    drift = random.uniform(-0.001, 0.003) if is_bond else random.uniform(-0.01, 0.015)
    level = float(base_nav)
    for d in SNAPSHOT_DATES:
        noise = random.uniform(-0.002, 0.002) if is_bond else random.uniform(-0.01, 0.01)
        level = round(level * (1 + drift + noise), 4)
        total_net_asset = round(level * random.uniform(500_000, 10_000_000), 2)
        units = random.uniform(500_000, 10_000_000)
        fund_nav_history.append((d, fid, level, total_net_asset, round(units, 4)))

oef_customers = random.sample(customers, 400)
oef_accounts = []
for idx, c in enumerate(oef_customers, start=1):
    customer_code = c[0]
    oef_accounts.append((idx, f"0003{idx:06d}", customer_code, customer_current_broker[customer_code], c[6]))

oef_acct_pool = account_weight_pool(oef_accounts, {"VIP": 4, "PRIORITY": 2, "RETAIL": 1})
oef_acct_by_id = {a[0]: a for a in oef_accounts}
fund_by_id = {f[0]: f for f in funds}
nav_by_fund_date = {(fid, d): nav for (d, fid, nav, *_r) in fund_nav_history}
fund_weight_pool = []
for f in funds:
    fund_weight_pool.extend([f[0]] * (8 if f[0] <= 2 else 1))

oef_trade = []
trade_counter = 0
for m in MONTHS_2027:
    tdays = trading_days_in_month(2027, m)
    for _ in range(1000):
        trade_counter += 1
        trade_date = random.choice(tdays)
        acct_id = random.choice(oef_acct_pool)
        acct = oef_acct_by_id[acct_id]
        fid = random.choice(fund_weight_pool)
        fund = fund_by_id[fid]
        roll = random.randint(0, 99)
        ttype = "SUBSCRIBE" if roll < 55 else ("REDEEM" if roll < 95 else "SWITCH")
        amount = round(random.uniform(1_000_000, 500_000_000), 2)
        nav_price = nav_by_fund_date.get((fid, SNAPSHOT_DATES[m - 1]), fund[6])
        quantity_unit = round(amount / nav_price, 4)
        trade_dt = f"{trade_date.isoformat()}T{random.randint(9,14):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"
        source_trade_id = f"OEF-{m:02d}2027-{trade_counter:07d}"
        oef_trade.append((
            trade_date, trade_dt, source_trade_id, acct[1], acct[2], acct[3], fid, ttype,
            quantity_unit, nav_price, amount, 0, trade_date + timedelta(days=3),
            f"ORD-{m:02d}2027-{trade_counter}", "OEF",
        ))

oef_balance = []
oef_wealth = {a[0]: (random.uniform(1_000_000, 50_000_000), random.uniform(20_000_000, 500_000_000)) for a in oef_accounts}
for d in SNAPSHOT_DATES:
    for acc in oef_accounts:
        base_cash, base_port = oef_wealth[acc[0]]
        cash = round(base_cash * random.uniform(0.95, 1.05), 2)
        port = round(base_port * random.uniform(0.97, 1.03), 2)
        oef_balance.append((d, acc[0], cash, port, round(cash + port, 2)))

oef_position_accounts = oef_accounts[:150]
oef_holdings = {}
for acc in oef_position_accounts:
    n_hold = random.randint(1, 2)
    oef_holdings[acc[0]] = random.sample([f[0] for f in funds], n_hold)

oef_position = []
for d in SNAPSHOT_DATES:
    for acc in oef_position_accounts:
        for fid in oef_holdings[acc[0]]:
            fund = fund_by_id[fid]
            units = round(random.uniform(10, 5000), 4)
            cost = fund[6]
            mv = round(units * nav_by_fund_date.get((fid, d), cost), 2)
            oef_position.append((d, acc[0], fid, units, cost, mv))

with open(f"{OUT_DIR}/04_oef_sample.sql", "w", encoding="utf-8") as f:
    f.write("USE SSI_OEF;\nGO\n\n")
    f.write("-- Static literal sample data - see generate_static_sample.py. Requires\n")
    f.write("-- StaticSampleData/01_common_sample.sql to have been run first.\n")
    f.write("-- Alternative to Database/OEF/06_seed_sample_data.sql / 07_seed_at_scale.sql.\n")
    f.write("-- No margin_loan_daily - OEF certificates are not traded on margin.\n\n")
    emit_inserts(f, "raw.fund", ["fund_code", "fund_name", "fund_type", "fund_manager", "inception_date"],
                 [(fu[1], fu[2], fu[3], fu[4], fu[5]) for fu in funds])
    emit_inserts(f, "raw.fund_nav_history", ["nav_date", "fund_id", "nav_price", "total_net_asset", "outstanding_units"], fund_nav_history)
    emit_inserts(f, "raw.account", ["account_no", "customer_code", "broker_code", "open_date"],
                 [(a[1], a[2], a[3], a[4]) for a in oef_accounts])
    emit_inserts(f, "raw.oef_trade", [
        "trade_date", "trade_datetime", "source_trade_id", "account_no", "customer_code", "broker_code",
        "fund_id", "transaction_type", "quantity_unit", "nav_price", "amount", "fee_amount",
        "settlement_date", "order_id", "source_system"], oef_trade)
    emit_inserts(f, "raw.account_balance_daily", ["balance_date", "account_id", "cash_balance", "portfolio_value", "total_asset_value"], oef_balance)
    emit_inserts(f, "raw.position_daily", ["position_date", "account_id", "fund_id", "quantity_unit", "avg_cost_nav", "market_value"], oef_position)

print(f"OEF: funds={len(funds)} nav_history={len(fund_nav_history)} accounts={len(oef_accounts)} "
      f"trades={len(oef_trade)} balance={len(oef_balance)} position={len(oef_position)}")
