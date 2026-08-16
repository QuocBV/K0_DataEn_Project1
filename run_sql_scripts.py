"""Run all Database SQL scripts in order using sqlcmd."""
import subprocess, sys

SERVER = "localhost"
USER = "sa"
PASSWORD = "123456789"

def run_sql(script_path, db="master"):
    print(f"\n{'='*70}\n[RUN] {script_path} (db={db})")
    cmd = [
        "sqlcmd", "-S", SERVER, "-U", USER, "-P", PASSWORD,
        "-d", db, "-i", script_path, "-b", "-I"
    ]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"[ERROR] {script_path}\n{r.stdout}\n{r.stderr}")
        sys.exit(1)
    # Only print last lines
    out = r.stdout.strip().splitlines()
    if out:
        for line in out[-5:]:
            print(f"  {line}")
    print(f"[OK] {script_path}")
    return True

# Step 1: Drop old databases first (clean slate)
drop_sql = """
IF DB_ID('SSI_Common') IS NOT NULL BEGIN ALTER DATABASE [SSI_Common] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_Common]; END
IF DB_ID('SSI_Equity') IS NOT NULL BEGIN ALTER DATABASE [SSI_Equity] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_Equity]; END
IF DB_ID('SSI_Derivatives') IS NOT NULL BEGIN ALTER DATABASE [SSI_Derivatives] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_Derivatives]; END
IF DB_ID('SSI_OEF') IS NOT NULL BEGIN ALTER DATABASE [SSI_OEF] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_OEF]; END
"""
subprocess.run([
    "sqlcmd", "-S", SERVER, "-U", USER, "-P", PASSWORD,
    "-d", "master", "-Q", drop_sql, "-b", "-I"
], capture_output=True, text=True)
print("[OK] Dropped old SSI databases")

# Step 2: Create databases
run_sql("Database/00_create_databases.sql")

# Step 3: Common schema
common_files = [
    "Database/Common/01_schema_init.sql",
    "Database/Common/02_organization.sql",
    "Database/Common/03_broker.sql",
    "Database/Common/04_customer.sql",
    "Database/Common/04b_account.sql",
    "Database/Common/05_customer_classification.sql",
    "Database/Common/06_market_reference.sql",
    "Database/Common/07_fee_schedule.sql",
    "Database/Common/08_compliance_service.sql",
]
for f in common_files:
    run_sql(f)

# Step 4: Equity schema
equity_files = [
    "Database/Equity/01_schema_init.sql",
    "Database/Equity/02_partition_helper.sql",
    "Database/Equity/03_instrument_master.sql",
    "Database/Equity/04_account_position.sql",
    "Database/Equity/05_equity_trade.sql",
]
for f in equity_files:
    run_sql(f)

# Step 5: Derivatives schema
deriv_files = [
    "Database/Derivatives/01_schema_init.sql",
    "Database/Derivatives/02_partition_helper.sql",
    "Database/Derivatives/03_instrument_master.sql",
    "Database/Derivatives/04_account_position.sql",
    "Database/Derivatives/05_derivative_trade.sql",
]
for f in deriv_files:
    run_sql(f)

# Step 6: OEF schema
oef_files = [
    "Database/OEF/01_schema_init.sql",
    "Database/OEF/02_partition_helper.sql",
    "Database/OEF/03_instrument_master.sql",
    "Database/OEF/04_account_position.sql",
    "Database/OEF/05_oef_trade.sql",
]
for f in oef_files:
    run_sql(f)

print("\n\n=== ALL SCHEMA DDL COMPLETED ===")