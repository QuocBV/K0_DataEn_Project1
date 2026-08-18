"""Check that Dagster code can load assets and discover Airbyte connections."""
import os, sys

sys.path.insert(0, r"D:\DE\K20Learn\Project_De\data-platform\dagster")
os.environ.setdefault("AIRBYTE_HOST", "host.docker.internal")
os.environ.setdefault("AIRBYTE_PORT", "8001")
os.environ.setdefault("AIRBYTE_USER", "airbyte")
os.environ.setdefault("AIRBYTE_PASSWORD", "password")

try:
    import resources
    print("resources imported OK")
    print("AirbyteResource host:", resources.airbyte_resource.host, "port:", resources.airbyte_resource.port)
except Exception as e:
    print("resources FAIL:", e)