"""Check SSI databases; recreate schema + seed sample data if missing."""
import subprocess, sys, os

SERVER = "localhost"
USER = "sa"
PASSWORD = "123456789"

def run_sql(sql, db="master"):
    cmd = ["sqlcmd", "-S", SERVER, "-U", USER, "-P", PASSWORD, "-d", db,
           "-Q", sql, "-b", "-I"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r

# 1. Check SSI databases exist
r = run_sql("SELECT COUNT(*) FROM sys.databases WHERE name LIKE 'SSI%'")
print("=== Check SSI DBs ===")
print("RC", r.returncode)
print(r.stdout[-300:] if r.stdout else "", r.stderr[-200:] if r.stderr else "")

# Parse count
count = 0
if r.stdout:
    lines = [l.strip() for l in r.stdout.splitlines() if l.strip()]
    # last data line before 'rows affected'
    for l in lines:
        if l.isdigit():
            count = int(l)

print(f"SSI databases found: {count}/4")

if count < 4:
    print("\n=== Recreating databases + schema + seed ===")
    # Drop if partial, then create
    drop = """
IF DB_ID('SSI_Common') IS NOT NULL BEGIN ALTER DATABASE [SSI_Common] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_Common]; END
IF DB_ID('SSI_Equity') IS NOT NULL BEGIN ALTER DATABASE [SSI_Equity] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_Equity]; END
IF DB_ID('SSI_Derivatives') IS NOT NULL BEGIN ALTER DATABASE [SSI_Derivatives] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_Derivatives]; END
IF DB_ID('SSI_OEF') IS NOT NULL BEGIN ALTER DATABASE [SSI_OEF] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [SSI_OEF]; END
"""
    run_sql(drop)
    print("[OK] Dropped old SSI databases")

    # Run schema DDL script
    r = subprocess.run(["python", "run_sql_scripts.py"], capture_output=True, text=True)
    print("schema:", r.stdout[-300:] if r.stdout else "", r.stderr[-300:] if r.stderr else "")

    # Seed StaticSampleData
    seed_files = [
        "Database/StaticSampleData/01_common_sample.sql",
        "Database/StaticSampleData/02_equity_sample.sql",
        "Database/StaticSampleData/03_derivatives_sample.sql",
        "Database/StaticSampleData/04_oef_sample.sql",
    ]
    for f in seed_files:
        cmd = ["sqlcmd", "-S", SERVER, "-U", USER, "-P", PASSWORD, "-d", "master",
               "-i", f, "-b", "-I"]
        rr = subprocess.run(cmd, capture_output=True, text=True)
        print(f"[seed] {f}: rc={rr.returncode}")
        if rr.returncode != 0:
            print("   ", rr.stderr[-300:])

    print("\n=== DONE ===")
else:
    print("All 4 SSI databases present - skipping re-init")