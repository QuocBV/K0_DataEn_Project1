"""Dagster resources: Airbyte, dbt, Trino."""
import os
import requests
from dagster_airbyte import AirbyteResource
from dagster_dbt import DbtCliResource

AIRBYTE_HOST = os.getenv("AIRBYTE_HOST", "host.docker.internal")
AIRBYTE_PORT = os.getenv("AIRBYTE_PORT", "8001")
AIRBYTE_USER = os.getenv("AIRBYTE_USER", "airbyte")
AIRBYTE_PASSWORD = os.getenv("AIRBYTE_PASSWORD", "password")

airbyte_resource = AirbyteResource(
    host=AIRBYTE_HOST,
    port=AIRBYTE_PORT,
    username=AIRBYTE_USER,
    password=AIRBYTE_PASSWORD,
)


def _airbyte_api(path, payload):
    """POST to Airbyte internal API with basic auth."""
    url = f"http://{AIRBYTE_HOST}:{AIRBYTE_PORT}/api/v1/{path}"
    r = requests.post(url, json=payload, auth=(AIRBYTE_USER, AIRBYTE_PASSWORD), timeout=30)
    r.raise_for_status()
    return r.json()


def list_airbyte_connections():
    """Discover all Airbyte connections (name + connectionId)."""
    ws = _airbyte_api("workspaces/list", {})
    workspace_id = ws["workspaces"][0]["workspaceId"]
    data = _airbyte_api("connections/list", {"workspaceId": workspace_id})
    conns = []
    for c in data.get("connections", []):
        name = c.get("name", "")
        cid = c.get("connectionId", "")
        conns.append({"name": name, "connection_id": cid})
    return conns


def mssql_connections():
    """Filter only MSSQL -> S3 connections."""
    out = []
    for c in list_airbyte_connections():
        n = (c["name"] or "").lower()
        if any(k in n for k in ("mssql", "ssi", "common", "equity", "derivatives", "oef")):
            out.append(c)
    return out


dbt_resource = DbtCliResource(
    project_dir=os.getenv("DBT_PROJECT_DIR", "/opt/airflow/data-platform/dbt"),
    profiles_dir=os.getenv("DBT_PROFILES_DIR", "/root/.dbt"),
)