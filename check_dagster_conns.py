"""Check Dagster UI + Airbyte connections discoverable from host."""
import subprocess, os, urllib.request

env = dict(os.environ)
env["PATH"] = r"C:\Users\Lucifer\AppData\Local\Programs\DockerDesktop\resources\bin;" + env.get("PATH", "")

lines = []

# 1. Dagster UI
try:
    r = urllib.request.urlopen("http://localhost:3000", timeout=12)
    lines.append(f"Dagster UI: {r.status}")
except Exception as e:
    lines.append(f"Dagster UI FAIL: {e}")

# 2. Tự nhận connections từ container dagster
try:
    r2 = subprocess.run(
        ["docker", "exec", "project_de-dagster-code-location-1", "python", "/opt/dagster/_list_"],
        capture_output=True, env=env, timeout=60,
    )
    lines.append("Airbyte connections discoverable:")
    lines.append(r2.stdout.decode("utf-8", errors="replace"))
    if r2.stderr.decode("utf-8", errors="replace").strip():
        lines.append("ERR: " + r2.stderr.decode("utf-8", errors="replace")[:300])
except Exception as e:
    lines.append(f"exec FAIL: {e}")

# Write result to file to avoid lost output
with open("dagster_check_result.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("\n".join(lines))