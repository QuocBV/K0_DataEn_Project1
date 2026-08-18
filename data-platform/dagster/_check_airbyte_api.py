"""Check available airbyte asset builder APIs in this dagster=1.7.14 environment."""
import dagster_airbyte as da
print("top-level:", [x for x in dir(da) if "asset" in x.lower() or "connection" in x.lower()])

try:
    from dagster_airbyte import build_airbyte_assets
    print("build_airbyte_assets: OK")
except ImportError as e:
    print("build_airbyte_assets: MISSING", e)

try:
    from dagster_airbyte.assets import build_airbyte_assets
    print("build_airbyte_assets (sub): OK")
except ImportError as e:
    print("build_airbyte_assets (sub): MISSING", e)

try:
    from dagster_airbyte import load_assets_from_connections
    print("load_assets_from_connections: OK")
except ImportError as e:
    print("load_assets_from_connections: MISSING", e)

# Check AirbyteResource methods
print("AirbyteResource methods:", [x for x in dir(da.AirbyteResource) if not x.startswith("_")])