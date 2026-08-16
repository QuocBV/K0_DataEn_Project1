"""Download Airbyte support files (flags.yml, temporal dynamicconfig, configs dir)."""
import os, urllib.request

BASE = "https://raw.githubusercontent.com/airbytehq/airbyte-platform/v0.50.43"
files = {
    "flags.yml": "flags.yml",
    "temporal/dynamicconfig/development.yaml": "temporal/dynamicconfig/development.yaml",
}

for path, rel in files.items():
    url = f"{BASE}/{path}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "python"})
        data = urllib.request.urlopen(req, timeout=30).read().decode("utf-8")
        os.makedirs(os.path.dirname(rel) if os.path.dirname(rel) else ".", exist_ok=True)
        with open(rel, "w", encoding="utf-8") as f:
            f.write(data)
        print(f"[OK] {rel} ({len(data)}B)")
    except Exception as e:
        print(f"[FAIL] {path}: {e}")