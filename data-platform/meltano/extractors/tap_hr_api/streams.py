"""Stream classes for tap-hr-api."""
from __future__ import annotations

import requests
from singer_sdk import typing as th
from singer_sdk.streams import RESTStream


class EmployeesStream(RESTStream):
    """Stream for fetching all employees from /employees."""

    name = "employees"
    path = "/employees"
    primary_keys = ["id_number"]
    replication_key = None  # Full refresh (list is small)

    schema = th.PropertiesList(
        th.Property("id_number", th.StringType),
        th.Property("employee_code", th.StringType),
        th.Property("full_name", th.StringType),
        th.Property("person_type", th.StringType),
        th.Property("branch_code", th.StringType),
        th.Property("branch_name", th.StringType),
        th.Property("department_code", th.StringType),
        th.Property("department_name", th.StringType),
        th.Property("position", th.StringType),
        th.Property("position_code", th.StringType),
        th.Property("position_level", th.StringType),
        th.Property("manager_employee_code", th.StringType),
        th.Property("start_date", th.StringType),
        th.Property("end_date", th.StringType),
        th.Property("status", th.StringType),
    ).to_dict()

    def get_url(self, context: dict | None) -> str:
        return f"{self.config['api_base_url']}/employees"

    def request_kwargs(self, context, **kwargs) -> dict:
        headers = {}
        auth_mode = self.config.get("auth_mode", "none")
        if auth_mode == "api_key":
            headers["X-API-Key"] = self.config["api_key"]
        elif auth_mode == "jwt":
            import jwt as pyjwt
            token = pyjwt.encode({"sub": "meltano"}, self.config["jwt_secret"], algorithm="HS256")
            headers["Authorization"] = f"Bearer {token}"
        return {"headers": headers}


class ManagerChainStream(RESTStream):
    """Stream for fetching manager chain for each employee."""

    name = "manager_chain"
    path = "/employees/{id_number}/manager-chain"
    primary_keys = ["id_number"]
    replication_key = None

    schema = th.PropertiesList(
        th.Property("id_number", th.StringType),
        th.Property("employee_code", th.StringType),
        th.Property("full_name", th.StringType),
        th.Property("person_type", th.StringType),
        th.Property("branch_code", th.StringType),
        th.Property("branch_name", th.StringType),
        th.Property("department_code", th.StringType),
        th.Property("department_name", th.StringType),
        th.Property("position", th.StringType),
        th.Property("position_code", th.StringType),
        th.Property("position_level", th.StringType),
        th.Property("manager_employee_code", th.StringType),
        th.Property("start_date", th.StringType),
        th.Property("end_date", th.StringType),
        th.Property("status", th.StringType),
    ).to_dict()

    def get_url(self, context: dict | None) -> str:
        if context is None or "id_number" not in context:
            raise ValueError("ManagerChainStream requires context id_number")
        return f"{self.config['api_base_url']}/employees/{context['id_number']}/manager-chain"

    def request_kwargs(self, context, **kwargs) -> dict:
        headers = {}
        auth_mode = self.config.get("auth_mode", "none")
        if auth_mode == "api_key":
            headers["X-API-Key"] = self.config["api_key"]
        elif auth_mode == "jwt":
            import jwt as pyjwt
            token = pyjwt.encode({"sub": "meltano"}, self.config["jwt_secret"], algorithm="HS256")
            headers["Authorization"] = f"Bearer {token}"
        return {"headers": headers}

    def get_child_context(self, record, context):
        """Provide id_number for the parent record to children."""
        return {"id_number": record["id_number"]}
