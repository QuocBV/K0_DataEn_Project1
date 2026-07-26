"""Export one date partition of a heavy SQL Server raw table to a Parquet file for bulk loading
into Snowflake, instead of replicating it row-by-row through a JDBC source connector.

Usage:
    python export_partition_to_parquet.py --database SSI_Equity --schema raw --table equity_trade \
        --date-column trade_date --partition-date 2026-07-17 --output-uri abfss://landing@ssidl.dfs.core.windows.net/equity_trade

Design notes (why this exists instead of plain Airbyte JDBC sync):
- equity_trade / derivative_trade / oef_trade / account_balance_daily / position_daily /
  margin_loan_daily can reach tens of millions of rows a month; JDBC row-based replication is slow
  and puts read load on the trading source DB during market hours.
- Exporting one file per source partition (trade_date) mirrors the SQL Server monthly partitioning
  already in place, so re-running an export only touches one partition worth of data.
- The output file name is deterministic (table/dt=<date>/part-0000.parquet) so re-running this
  script for the same partition overwrites the same file. Snowflake's COPY INTO tracks loaded file
  names+checksums for 64 days and skips already-loaded files, making retries safe (no duplicate rows).
- Credentials come from environment variables only (vault-injected), never hardcoded.
"""
import argparse
import os
import sys

import pyodbc
import pyarrow as pa
import pyarrow.parquet as pq


def build_connection_string(database: str) -> str:
    host = os.environ["MSSQL_HOST"]
    user = os.environ["MSSQL_EXPORT_USER"]
    password = os.environ["MSSQL_EXPORT_PASSWORD"]
    return (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={host};DATABASE={database};UID={user};PWD={password};"
        f"Encrypt=yes;TrustServerCertificate=no;"
    )


def export_partition(database: str, schema: str, table: str, date_column: str,
                      partition_date: str, output_uri: str) -> str:
    query = (
        f"SELECT * FROM {schema}.{table} "
        f"WHERE {date_column} = ?"
    )
    conn = pyodbc.connect(build_connection_string(database))
    try:
        cursor = conn.cursor()
        cursor.execute(query, partition_date)
        columns = [d[0] for d in cursor.description]
        rows = cursor.fetchall()
    finally:
        conn.close()

    if not rows:
        print(f"No rows for {database}.{schema}.{table} on {partition_date} - skipping file write.")
        return ""

    arrays = [pa.array([row[i] for row in rows]) for i in range(len(columns))]
    table_data = pa.Table.from_arrays(arrays, names=columns)

    file_path = f"{output_uri.rstrip('/')}/{table}/dt={partition_date}/part-0000.parquet"
    pq.write_table(table_data, file_path, compression="snappy")
    print(f"Exported {len(rows)} rows to {file_path}")
    return file_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", required=True)
    parser.add_argument("--schema", default="raw")
    parser.add_argument("--table", required=True)
    parser.add_argument("--date-column", required=True)
    parser.add_argument("--partition-date", required=True, help="YYYY-MM-DD")
    parser.add_argument("--output-uri", required=True, help="Base path/URI of the landing stage")
    args = parser.parse_args()

    file_path = export_partition(
        database=args.database,
        schema=args.schema,
        table=args.table,
        date_column=args.date_column,
        partition_date=args.partition_date,
        output_uri=args.output_uri,
    )
    if not file_path:
        sys.exit(0)


if __name__ == "__main__":
    main()
