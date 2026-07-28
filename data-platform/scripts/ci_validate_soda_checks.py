#!/usr/bin/env python3
"""CI script: validate Soda checks YAML structure.
Called from pipeline_ci.yml - no Snowflake connection needed."""

import sys
import yaml
import glob


def main() -> None:
    check_files = glob.glob("data-platform/soda/checks/*.yml")
    if not check_files:
        print("No Soda check files found in data-platform/soda/checks/")
        sys.exit(1)

    all_ok = True
    for fpath in check_files:
        print(f"=== Checking {fpath} ===")
        try:
            with open(fpath) as fh:
                data = yaml.safe_load(fh)
            for table, checks in data.items():
                if not table.startswith("checks for"):
                    raise ValueError(f"Missing 'checks for' header in {table}")
                if not isinstance(checks, list) or len(checks) == 0:
                    raise ValueError(f"No checks defined for {table}")
            print("  Valid")
        except Exception as e:
            print(f"  ERROR: {e}")
            all_ok = False

    if not all_ok:
        sys.exit(1)

    print("All Soda check files validated successfully.")


if __name__ == "__main__":
    main()