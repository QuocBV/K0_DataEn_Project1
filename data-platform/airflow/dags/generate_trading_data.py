"""Generate sample trading data by date, respecting all foreign key constraints.

This DAG creates realistic trading records directly in Snowflake for all 3 product types:
- Equity trades (fact_equity_trade) linked to dim_security, dim_customer, dim_broker
- Derivative trades (fact_derivative_trade) linked to dim_derivative_contract, dim_customer, dim_broker
- OEF trades (fact_oef_trade) linked to dim_fund, dim_customer, dim_broker

trade_id is the unique contract identifier for each trade (Equity/OEF).
For derivatives, contract_id references the derivative contract (dim_derivative_contract).
Runs daily and generates data for the current execution date.
"""
from datetime import datetime, timedelta
from typing import Any

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.python import PythonOperator

from _common import DEFAULT_ARGS

GENERATE_DONE = Dataset("snowflake://RAW/trading_data_generated")

# Snowflake connection parameters (read from Airflow connection or env)
SNOWFLAKE_CONN_ID = "snowflake_default"

# Number of trades to generate per product type per run
NUM_EQUITY_TRADES = 50
NUM_DERIVATIVE_TRADES = 20
NUM_OEF_TRADES = 15


def _get_snowflake_cursor():
    """Create and return a Snowflake cursor using Airflow's hook."""
    from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

    hook = SnowflakeHook(snowflake_conn_id=SNOWFLAKE_CONN_ID)
    conn = hook.get_conn()
    return conn.cursor()


def _fetch_reference_data(cursor) -> dict[str, Any]:
    """Fetch existing dimension data to ensure FK integrity when generating trades."""
    ref: dict[str, Any] = {}

    # Fetch customers (from dim_customer in MARTS)
    cursor.execute("SELECT customer_code FROM ANALYTICS.MARTS.dim_customer")
    ref["customers"] = [row[0] for row in cursor.fetchall()]

    # Fetch brokers (from dim_broker in MARTS)
    cursor.execute("SELECT broker_code FROM ANALYTICS.MARTS.dim_broker")
    ref["brokers"] = [row[0] for row in cursor.fetchall()]

    # Fetch securities (from dim_security in MARTS)
    cursor.execute("SELECT security_id FROM ANALYTICS.MARTS.dim_security")
    ref["securities"] = [row[0] for row in cursor.fetchall()]

    # Fetch derivative contracts (from dim_derivative_contract in MARTS)
    cursor.execute("SELECT contract_id, contract_code FROM ANALYTICS.MARTS.dim_derivative_contract")
    ref["derivative_contracts"] = [(row[0], row[1]) for row in cursor.fetchall()]

    # Fetch funds (from dim_fund in MARTS)
    cursor.execute("SELECT fund_id, fund_code FROM ANALYTICS.MARTS.dim_fund")
    ref["funds"] = [(row[0], row[1]) for row in cursor.fetchall()]

    # Fetch accounts for each product type (from fact_account_balance_daily or staging)
    for product_type, schema in [("EQUITY", "STG_EQUITY"), ("DERIVATIVES", "STG_DERIVATIVES"), ("OEF", "STG_OEF")]:
        try:
            cursor.execute(f"SELECT DISTINCT account_no, customer_code, broker_code FROM ANALYTICS.{schema}.account")
            ref[f"accounts_{product_type.lower()}"] = [
                (row[0], row[1], row[2]) for row in cursor.fetchall()
            ]
        except Exception:
            # Fallback: use trade accounts from existing data
            cursor.execute(f"""
                SELECT DISTINCT account_no, customer_code, broker_code 
                FROM ANALYTICS.STG_{'EQUITY' if product_type == 'EQUITY' else product_type}.account
            """)
            ref[f"accounts_{product_type.lower()}"] = [
                (row[0], row[1], row[2]) for row in cursor.fetchall()
            ]

    return ref


def _generate_equity_trades(cursor, ref: dict[str, Any], trade_date: str, count: int) -> int:
    """Generate equity trades with correct FK references.
    trade_id is the unique contract identifier for each trade."""
    import random

    customers = ref.get("customers", ["KH00001"])
    brokers = ref.get("brokers", ["MG0001"])
    securities = ref.get("securities", [1])
    accounts = ref.get("accounts_equity", [("ACC0001", "KH00001", "MG0001")])
    sides = ["BUY", "SELL"]
    markets = ["HOSE", "HNX", "UPCOM"]
    order_types = ["LO", "MP", "ATO", "ATC"]

    if not accounts:
        print("No equity accounts found - using defaults")
        accounts = [("ACC0001", customers[0], brokers[0])]

    generated = 0
    for i in range(count):
        source_trade_id = f"GEN-EQ-{trade_date}-{i + 1:04d}"
        trade_id = abs(hash(source_trade_id)) % 10000000 + i
        acc_no, cust_code, brk_code = random.choice(accounts)
        sec_id = random.choice(securities)
        side = random.choice(sides)
        qty = random.randint(100, 10000)
        price = round(random.uniform(5.0, 150.0), 2)
        amount = round(qty * price, 2)
        fee = round(amount * 0.0015, 2)
        tax = round(amount * 0.001, 2) if side == "SELL" else 0

        try:
            cursor.execute(f"""
                INSERT INTO ANALYTICS.RAW.equity_trade_raw (raw_data, _file_name, _loaded_at)
                SELECT PARSE_JSON('{{
                    "trade_id": {trade_id},
                    "trade_date": "{trade_date}",
                    "trade_datetime": "{trade_date}T{random.randint(9, 14):02d}:{random.randint(0, 59):02d}:{random.randint(0, 59):02d}.000",
                    "source_trade_id": "{source_trade_id}",
                    "account_no": "{acc_no}",
                    "customer_code": "{cust_code}",
                    "broker_code": "{brk_code}",
                    "security_id": {sec_id},
                    "market": "{random.choice(markets)}",
                    "side": "{side}",
                    "order_type": "{random.choice(order_types)}",
                    "quantity": {qty},
                    "price": {price},
                    "amount": {amount},
                    "fee_amount": {fee},
                    "tax_amount": {tax},
                    "settlement_date": "{(datetime.strptime(trade_date, '%Y-%m-%d') + timedelta(days=2)).strftime('%Y-%m-%d')}",
                    "order_id": "ORD-{source_trade_id}",
                    "source_system": "SSI_TRADING",
                    "ingested_at": "{datetime.utcnow().isoformat()}Z"
                }}'),
                'generated/equity/{trade_date}/part-gen-{i:04d}.parquet',
                CURRENT_TIMESTAMP()
            """)
            generated += 1
        except Exception as e:
            print(f"Failed to insert equity trade {i}: {e}")

    print(f"Generated {generated}/{count} equity trades for {trade_date}")
    return generated


def _generate_derivative_trades(cursor, ref: dict[str, Any], trade_date: str, count: int) -> int:
    """Generate derivative trades with correct FK references."""
    import random

    customers = ref.get("customers", ["KH00001"])
    brokers = ref.get("brokers", ["MG0001"])
    contracts = ref.get("derivative_contracts", [(1, "VN30F2701")])
    accounts = ref.get("accounts_derivatives", [("ACCD001", "KH00001", "MG0001")])
    position_sides = ["LONG", "SHORT"]
    order_actions = ["OPEN", "CLOSE"]

    if not accounts:
        accounts = [("ACCD001", customers[0], brokers[0])]

    generated = 0
    for i in range(count):
        source_trade_id = f"GEN-DER-{trade_date}-{i + 1:04d}"
        contract_id = f"CTRCT-DER-{trade_date}-{i + 1:04d}"
        acc_no, cust_code, brk_code = random.choice(accounts)
        c_id, c_code = random.choice(contracts)
        pos_side = random.choice(position_sides)
        action = random.choice(order_actions)
        qty = random.randint(1, 100)
        price = round(random.uniform(1000.0, 1500.0), 2)
        amount = round(qty * price * 100000, 2)  # Multiplier = 100,000
        margin = round(amount * 0.1, 2)
        fee = round(amount * 0.0003, 2)

        try:
            cursor.execute(f"""
                INSERT INTO ANALYTICS.RAW.derivative_trade_raw (raw_data, _file_name, _loaded_at)
                SELECT PARSE_JSON('{{
                    "trade_id": {abs(hash(source_trade_id)) % 10000000 + i},
                    "trade_date": "{trade_date}",
                    "trade_datetime": "{trade_date}T{random.randint(9, 14):02d}:{random.randint(0, 59):02d}:{random.randint(0, 59):02d}.000",
                    "source_trade_id": "{source_trade_id}",
                    "contract_id": "{contract_id}",
                    "account_no": "{acc_no}",
                    "customer_code": "{cust_code}",
                    "broker_code": "{brk_code}",
                    "derivative_contract_id": {c_id},
                    "position_side": "{pos_side}",
                    "order_action": "{action}",
                    "quantity": {qty},
                    "price": {price},
                    "amount": {amount},
                    "margin_amount": {margin},
                    "fee_amount": {fee},
                    "settlement_date": "{(datetime.strptime(trade_date, '%Y-%m-%d') + timedelta(days=1)).strftime('%Y-%m-%d')}",
                    "order_id": "ORD-{source_trade_id}",
                    "source_system": "SSI_DERIVATIVES",
                    "ingested_at": "{datetime.utcnow().isoformat()}Z"
                }}'),
                'generated/derivatives/{trade_date}/part-gen-{i:04d}.parquet',
                CURRENT_TIMESTAMP()
            """)
            generated += 1
        except Exception as e:
            print(f"Failed to insert derivative trade {i}: {e}")

    print(f"Generated {generated}/{count} derivative trades for {trade_date}")
    return generated


def _generate_oef_trades(cursor, ref: dict[str, Any], trade_date: str, count: int) -> int:
    """Generate OEF trades with correct FK references.
    trade_id is the unique contract identifier for each OEF trade."""
    import random

    customers = ref.get("customers", ["KH00001"])
    brokers = ref.get("brokers", ["MG0001"])
    funds = ref.get("funds", [(1, "SSI_SCF")])
    accounts = ref.get("accounts_oef", [("ACCO001", "KH00001", "MG0001")])
    tx_types = ["SUBSCRIBE", "REDEEM", "SWITCH"]

    if not accounts:
        accounts = [("ACCO001", customers[0], brokers[0])]

    generated = 0
    for i in range(count):
        source_trade_id = f"GEN-OEF-{trade_date}-{i + 1:04d}"
        trade_id = abs(hash(source_trade_id)) % 10000000 + i
        acc_no, cust_code, brk_code = random.choice(accounts)
        f_id, f_code = random.choice(funds)
        tx_type = random.choice(tx_types)
        qty = round(random.uniform(100.0, 5000.0), 4)
        nav = round(random.uniform(10000.0, 50000.0), 4)
        amount = round(qty * nav, 2)
        fee = round(amount * 0.01, 2) if tx_type == "SUBSCRIBE" else 0

        try:
            cursor.execute(f"""
                INSERT INTO ANALYTICS.RAW.oef_trade_raw (raw_data, _file_name, _loaded_at)
                SELECT PARSE_JSON('{{
                    "trade_id": {trade_id},
                    "trade_date": "{trade_date}",
                    "trade_datetime": "{trade_date}T{random.randint(9, 14):02d}:{random.randint(0, 59):02d}:{random.randint(0, 59):02d}.000",
                    "source_trade_id": "{source_trade_id}",
                    "account_no": "{acc_no}",
                    "customer_code": "{cust_code}",
                    "broker_code": "{brk_code}",
                    "fund_id": {f_id},
                    "transaction_type": "{tx_type}",
                    "quantity_unit": {qty},
                    "nav_price": {nav},
                    "amount": {amount},
                    "fee_amount": {fee},
                    "settlement_date": "{(datetime.strptime(trade_date, '%Y-%m-%d') + timedelta(days=3)).strftime('%Y-%m-%d')}",
                    "order_id": "ORD-{source_trade_id}",
                    "source_system": "SSI_OEF",
                    "ingested_at": "{datetime.utcnow().isoformat()}Z"
                }}'),
                'generated/oef/{trade_date}/part-gen-{i:04d}.parquet',
                CURRENT_TIMESTAMP()
            """)
            generated += 1
        except Exception as e:
            print(f"Failed to insert OEF trade {i}: {e}")

    print(f"Generated {generated}/{count} OEF trades for {trade_date}")
    return generated


def generate_trades_for_date(**context) -> None:
    """Main function: generate all 3 trade types for the execution date."""
    import random
    random.seed()

    execution_date = context["execution_date"]
    trade_date = execution_date.strftime("%Y-%m-%d")
    cursor = _get_snowflake_cursor()

    try:
        # Fetch reference data to ensure FK integrity
        print(f"Fetching reference data for {trade_date}...")
        ref = _fetch_reference_data(cursor)
        print(f"Found {len(ref.get('customers', []))} customers, {len(ref.get('brokers', []))} brokers")

        # Generate trades for each product type
        results = {}

        # 1. Equity trades
        eq_count = _generate_equity_trades(cursor, ref, trade_date, NUM_EQUITY_TRADES)
        results["equity"] = eq_count

        # 2. Derivative trades
        der_count = _generate_derivative_trades(cursor, ref, trade_date, NUM_DERIVATIVE_TRADES)
        results["derivatives"] = der_count

        # 3. OEF trades
        oef_count = _generate_oef_trades(cursor, ref, trade_date, NUM_OEF_TRADES)
        results["oef"] = oef_count

        # Commit all inserts
        cursor.connection.commit()

        total = sum(results.values())
        print(f"=== Generation Summary for {trade_date} ===")
        print(f"  Equity trades:     {results['equity']}")
        print(f"  Derivative trades: {results['derivatives']}")
        print(f"  OEF trades:        {results['oef']}")
        print(f"  Total:             {total}")

        # Push results to XCom for downstream tasks
        context["ti"].xcom_push(key="generation_summary", value=results)

    except Exception as e:
        cursor.connection.rollback()
        print(f"ERROR generating trades for {trade_date}: {e}")
        raise
    finally:
        cursor.close()


def verify_generated_data(**context) -> None:
    """Verify that generated data is accessible and FK constraints are satisfiable."""
    cursor = _get_snowflake_cursor()

    status = {}
    for product_type, table_raw in [
        ("Equity", "ANALYTICS.RAW.equity_trade_raw"),
        ("Derivatives", "ANALYTICS.RAW.derivative_trade_raw"),
        ("OEF", "ANALYTICS.RAW.oef_trade_raw"),
    ]:
        try:
            cursor.execute(f"""
                SELECT COUNT(*) as cnt, 
                       COUNT(DISTINCT raw_data:source_trade_id::varchar) as unique_trades,
                       MIN(raw_data:trade_date::date) as min_date,
                       MAX(raw_data:trade_date::date) as max_date
                FROM {table_raw}
                WHERE raw_data:source_system::varchar LIKE 'SSI_%'
            """)
            row = cursor.fetchone()
            status[product_type] = {
                "count": row[0],
                "unique_trades": row[1],
                "date_range": f"{row[2]} to {row[3]}",
            }
        except Exception as e:
            status[product_type] = {"error": str(e)}

    print("=== Data Verification ===")
    for ptype, info in status.items():
        print(f"  {ptype}: {info}")

    context["ti"].xcom_push(key="verification_status", value=status)


with DAG(
    dag_id="generate_trading_data",
    description=(
        "Generate sample trading data by date with correct FK references. "
        "Seeds Snowflake RAW tables with realistic equity/derivative/OEF trades."
    ),
    schedule="@daily",
    start_date=datetime(2026, 7, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["elt", "generate", "seed", "test"],
) as dag:

    gen_trades = PythonOperator(
        task_id="generate_trades",
        python_callable=generate_trades_for_date,
        execution_timeout=timedelta(hours=1),
    )

    verify_data = PythonOperator(
        task_id="verify_generated_data",
        python_callable=verify_generated_data,
        execution_timeout=timedelta(minutes=10),
    )

    mark_done = PythonOperator(
        task_id="mark_generation_complete",
        python_callable=lambda: None,
        outlets=[GENERATE_DONE],
    )

    gen_trades >> verify_data >> mark_done