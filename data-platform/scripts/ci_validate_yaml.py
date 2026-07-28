#!/usr/bin/env python3
"""CI script: validate all YAML files in the project.
Called from pipeline_ci.yml."""

import sys
import yaml
import os

FILES = [
    "docker-compose.yml",
    "data-platform/meltano/meltano.yml",
    "data-platform/soda/configuration.yml",
]


def main() -> None:
    all_ok = True
    for fpath in FILES:
        print(f"=== Validating {fpath} ===")
        if not os.path.exists(fpath):
            print(f"  SKIP (file not found: {fpath})")
            continue
        try:
            with open(fpath) as fh:
                yaml.safe_load(fh)
            print("  OK")
        except Exception as e:
            print(f"  ERROR: {e}")
            all_ok = False

    # Validate Soda check files
    import glob
    for fpath in glob.glob("data-platform/soda/checks/*.yml"):
        print(f"=== Validating {fpath} ===")
        try:
            with open(fpath) as fh:
                data = yaml.safe_load(fh)
            for table, checks in data.items():
                if not table.startswith("checks for"):
                    raise ValueError(f"Missing 'checks for' header in {table}")
                if not isinstance(checks, list) or len(checks) == 0:
                    raise ValueError(f"No checks defined for {table}")
            print("  OK")
        except Exception as e:
            print(f"  ERROR: {e}")
            all_ok = False

    if not all_ok:
        sys.exit(1)

    print("All YAML files validated successfully.")


if __name__ == "__main__":
    main()