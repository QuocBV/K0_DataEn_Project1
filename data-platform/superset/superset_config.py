import os

SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "change-me-in-prod")
SQLALCHEMY_DATABASE_URI = "sqlite:////app/superset_home/superset.db"

# Trino datasource (ssi_report with 13 report views)
TRINO_URI = os.getenv(
    "TRINO_URI",
    "trino://admin@trino:8080/ssi_report",
)

FEATURE_FLAGS = {"ENABLE_TEMPLATE_PROCESSING": True}
TALISMAN_ENABLED = False
AUTH_TYPE = 1  # Classic auth for local dev