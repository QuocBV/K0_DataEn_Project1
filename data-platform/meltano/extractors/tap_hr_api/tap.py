"""Singer tap for HR API - extracts employees from the mock FastAPI service.

This is a custom Singer tap built with the Meltano SDK (singer-sdk).
It fetches data from GET /employees and optionally GET /employees/{id_number}/manager-chain.
"""
from __future__ import annotations

import requests
from singer_sdk import Tap
from singer_sdk import typing as th

from tap_hr_api.streams import EmployeesStream, ManagerChainStream


class TapHRApi(Tap):
    """Singer tap for HR API."""

    name = "tap-hr-api"

    config_jsonschema = th.PropertiesList(
        th.Property(
            "api_base_url",
            th.StringType,
            required=True,
            description="Base URL of the HR API, e.g. http://hr-api:8000",
        ),
        th.Property(
            "auth_mode",
            th.StringType,
            default="none",
            description="Authentication mode: none, api_key, or jwt",
        ),
        th.Property(
            "api_key",
            th.StringType,
            description="API key (required if auth_mode=api_key)",
        ),
        th.Property(
            "jwt_secret",
            th.StringType,
            description="JWT secret (required if auth_mode=jwt)",
        ),
        th.Property(
            "start_date",
            th.DateTimeType,
            description="Earliest record date to replicate (not used for full-refresh)",
        ),
    ).to_dict()

    def discover_streams(self) -> list:
        """Return a list of discovered streams."""
        return [
            EmployeesStream(tap=self),
            ManagerChainStream(tap=self),
        ]


if __name__ == "__main__":
    TapHRApi.cli()
