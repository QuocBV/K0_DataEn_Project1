#!/bin/bash
set -e
export SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py

superset db upgrade
superset fab create-admin \
  --username admin --firstname Admin --lastname User \
  --email admin@ssi.com.vn --password admin || true
superset init

superset set-database-uri "Trino Reporting" "trino://admin@trino:8080/ssi_report" || true
echo "Superset init complete."