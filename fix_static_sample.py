"""
Fix StaticSampleData SQL files to match the NEW unified-account schema:
1. Remove raw.account INSERTs from product DBs (02/03/04) - the unified table lives in SSI_Common.
2. Convert account_id -> account_no in snapshot tables (account_balance_daily, position_daily,
   margin_loan_daily) using the account_id -> account_no mapping from the removed raw.account block.
3. Merge all account rows into 01_common_sample.sql with product_type.
"""
import re
from pathlib import Path

BASE = Path("Database") / "StaticSampleData"

SNAPSHOT_TABLES = {
    "raw.account_balance_daily",
    "raw.position_daily",
    "raw.margin_loan_daily",
}

INSERT_PAT = re.compile(
    r"INSERT INTO (\S+) \(([^)]+)\) VALUES\n(.*?);\n",
    re.S,
)
ROW_PAT = re.compile(r"\(([^)]+)\)")


def split_statements(content):
    """Return list of (table, header_cols, raw_row_strings)."""
    statements = []
    for m in INSERT_PAT.finditer(content):
        table = m.group(1)
        cols = [c.strip() for c in m.group(2).split(",")]
        rows = ROW_PAT.findall(m.group(3))
        statements.append((table, cols, rows))
    return statements


def main():
    all_accounts = {}  # product_type -> list of (account_no, customer_code, broker_code, open_date)

    for fname, product in [
        ("02_equity_sample.sql", "EQUITY"),
        ("03_derivatives_sample.sql", "DERIVATIVES"),
        ("04_oef_sample.sql", "OEF"),
    ]:
        path = BASE / fname
        content = path.read_text(encoding="utf-8")
        statements = split_statements(content)

        # Build account_id -> account_no mapping across ALL raw.account blocks.
        # account_id is 1-based sequential across blocks, so running_index tracks it.
        account_id_to_no = {}
        product_accounts = []
        running_count = 0

        # First pass: collect all account mappings in order
        for table, cols, rows in statements:
            if table == "raw.account":
                for r in rows:
                    running_count += 1
                    vals = [v.strip().strip("'") for v in r.split(",")]
                    account_id_to_no[str(running_count)] = vals[0]
                    product_accounts.append((vals[0], vals[1], vals[2], vals[3]))

        # Second pass: rewrite file, dropping account blocks and fixing snapshots
        new_statements = []
        for table, cols, rows in statements:
            if table == "raw.account":
                continue  # drop from product DB

            if table in SNAPSHOT_TABLES:
                # Rename header account_id -> account_no
                new_cols = ["account_no" if c == "account_id" else c for c in cols]
                new_rows = []
                for r in rows:
                    vals = r.split(",")
                    # Column 2 (index 1) is account_id
                    acct_id = vals[1].strip()
                    acct_no = account_id_to_no.get(acct_id)
                    if not acct_no:
                        raise ValueError(f"Unknown account_id={acct_id} in {fname}")
                    vals[1] = f"'{acct_no}'"
                    new_rows.append(", ".join(vv.strip() for vv in vals))
                new_statements.append((table, new_cols, new_rows))
            else:
                new_statements.append((table, cols, rows))

        # Write back the file (keep header before first INSERT, then regenerate statements)
        first_insert = content.index("INSERT INTO")
        header = content[:first_insert]
        out = [header]
        for table, cols, rows in new_statements:
            out.append(f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n")
            lines = ["    (" + r + ")" for r in rows]
            out.append(",\n".join(lines))
            out.append(";\n\n")
        path.write_text("".join(out), encoding="utf-8")

        all_accounts[product] = product_accounts
        print(f"[OK] {fname}: removed {len(statements) - len(new_statements)} account block(s), "
              f"converted snapshots, kept {len(product_accounts)} accounts")

    # Merge all accounts into 01_common_sample.sql
    common_path = BASE / "01_common_sample.sql"
    common = common_path.read_text(encoding="utf-8")
    lines = [common.rstrip(), "\n\n-- Unified raw.account rows (merged from product sample files)\n"]

    for product, accts in all_accounts.items():
        # Insert in chunks of 500 to keep statements manageable
        chunk_size = 500
        for start in range(0, len(accts), chunk_size):
            chunk = accts[start:start + chunk_size]
            lines.append(
                f"INSERT INTO raw.account (account_no, customer_code, broker_code, product_type, open_date) VALUES\n"
            )
            rows = [
                f"    ('{a[0]}', '{a[1]}', '{a[2]}', '{product}', '{a[3]}')"
                for a in chunk
            ]
            lines.append(",\n".join(rows))
            lines.append(";\n\n")

    common_path.write_text("".join(lines), encoding="utf-8")
    print("[OK] Merged all accounts into 01_common_sample.sql")
    print("\n=== FIX COMPLETE ===")


if __name__ == "__main__":
    main()