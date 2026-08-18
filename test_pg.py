"""Test psycopg2 connection to dagster-postgres from this container."""
import psycopg2
c = psycopg2.connect(
    host="dagster-postgres", port=5432,
    user="dagster", password="dagster_dev_password", dbname="dagster"
)
print("conn OK", c.get_dsn_parameters())
c.close()