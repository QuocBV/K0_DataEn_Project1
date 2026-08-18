"""Trigger Airbyte sync for the 4 MSSQL connections (same as Dagster ingest_raw orchestration)."""
import os, time, requests

HOST = os.getenv("AIRBYTE_HOST", "localhost")
PORT = os.getenv("AIRBYTE_PORT", "8001")
USER = os.getenv("AIRBYTE_USER", "airbyte")
PASS = os.getenv("AIRBYTE_PASSWORD", "password")
BASE = f"http://{HOST}:{PORT}/api/v1"

auth = (USER, PASS)

# 1. List connections
ws = requests.post(f"{BASE}/workspaces/list", json={}, auth=auth, timeout=30).json()
wid = ws["workspaces"][0]["workspaceId"]
conns = requests.post(f"{BASE}/connections/list", json={"workspaceId": wid}, auth=auth, timeout=30).json()

target = []
for c in conns.get("connections", []):
    name = c.get("name", "").lower()
    if any(k in name for k in ("mssql", "ssi", "common", "equity", "derivatives", "oef")):
        target.append(c)

print(f"Found {len(target)} MSSQL connections to sync")
for c in target:
    cid = c["connectionId"]
    name = c["name"]
    try:
        job = requests.post(f"{BASE}/connections/sync", json={"connectionId": cid}, auth=auth, timeout=60).json()
        jid = job.get("job", {}).get("id")
        print(f"[SYNC TRIGGERED] {name} -> job {jid}")
        time.sleep(45)  # parallel-ish; give each a head start
    except Exception as e:
        print(f"[FAIL] {name}: {e}")

print("Done - check connection sync status on Airbyte UI.")