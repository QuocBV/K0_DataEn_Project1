# ──────────────────────────────────────────────
# Apache Superset – Configuration for SSI Trading Analytics
# ──────────────────────────────────────────────
# This file is mounted into the superset container at /app/superset/superset_config.py
# and loaded automatically by the superset run command.

import os
from datetime import timedelta

# ─── Security ──────────────────────────────────
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "superset_secret_key_change_me")

# ─── Database ──────────────────────────────────
# Superset metadata database (PostgreSQL from docker-compose)
SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://superset:{os.environ.get('SUPERSET_DB_PASSWORD', 'supersetpass')}"
    f"@superset-postgres/superset"
)

# ─── Snowflake Connections (pre-configured) ────
# These will appear in Superset's 'Databases' menu once imported via API or UI.
# Alternatively, they can be added programmatically using the Superset REST API.
# For now, we list the connection parameters for manual setup.

SNOWFLAKE_CONNECTIONS = [
    {
        "database_name": "Analytics (Gold / BI)",
        "sqlalchemy_uri": (
            f"snowflake://{os.environ.get('SNOWFLAKE_TRANSFORM_USER', 'dbt_svc')}"
            f":{os.environ.get('SNOWFLAKE_TRANSFORM_PASSWORD', '')}"
            f"@{os.environ.get('SNOWFLAKE_ACCOUNT', '')}/ANALYTICS/MARTS"
            f"?warehouse=TRANSFORM_WH&role=TRANSFORM_ROLE"
        ),
        "expose_in_sqllab": True,
        "allow_dml": False,
        "allow_multi_schema_metadata_fetch": True,
        "cache_timeout": 3600,  # 1 hour
    },
    {
        "database_name": "Analytics (Silver / Staging)",
        "sqlalchemy_uri": (
            f"snowflake://{os.environ.get('SNOWFLAKE_TRANSFORM_USER', 'dbt_svc')}"
            f":{os.environ.get('SNOWFLAKE_TRANSFORM_PASSWORD', '')}"
            f"@{os.environ.get('SNOWFLAKE_ACCOUNT', '')}/ANALYTICS/STAGING"
            f"?warehouse=TRANSFORM_WH&role=TRANSFORM_ROLE"
        ),
        "expose_in_sqllab": True,
        "allow_dml": False,
        "cache_timeout": 3600,
    },
    {
        "database_name": "Analytics (Bronze / RAW for investigation)",
        "sqlalchemy_uri": (
            f"snowflake://{os.environ.get('SNOWFLAKE_TRANSFORM_USER', 'dbt_svc')}"
            f":{os.environ.get('SNOWFLAKE_TRANSFORM_PASSWORD', '')}"
            f"@{os.environ.get('SNOWFLAKE_ACCOUNT', '')}/ANALYTICS/RAW"
            f"?warehouse=TRANSFORM_WH&role=TRANSFORM_ROLE"
        ),
        "expose_in_sqllab": True,
        "allow_dml": False,
        "cache_timeout": 600,  # 10 minutes for raw data
    },
]

# ─── Feature Flags ──────────────────────────────
FEATURE_FLAGS = {
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "EMBEDDED_SUPERSET": True,
}

# ─── Cache ──────────────────────────────────────
# Use Redis if available (uncomment when Redis service is added)
# CACHE_CONFIG = {
#     "CACHE_TYPE": "RedisCache",
#     "CACHE_DEFAULT_TIMEOUT": 3600,
#     "CACHE_KEY_PREFIX": "superset_cache",
#     "CACHE_REDIS_URL": "redis://redis:6379/0",
# }
# For now, use simple null cache to avoid issues
CACHE_CONFIG = {
    "CACHE_TYPE": "NullCache",
}

# ─── Session ────────────────────────────────────
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = os.environ.get("SUPERSET_ENV", "dev").lower() == "production"

# ─── Rate Limiting ──────────────────────────────
# Enable if desired
# RATELIMIT_ENABLED = True

# ─── CSV/Excel Export ──────────────────────────
CSV_EXPORT = {"enabled": True, "max_bytes": 100_000_000}

# ─── Auth ───────────────────────────────────────
# Public role (uncomment to allow anonymous access)
# PUBLIC_ROLE_LIKE = "Gamma"
