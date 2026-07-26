import os
from typing import Optional

import jwt
from fastapi import Depends, FastAPI, HTTPException, Security
from fastapi.security import APIKeyHeader, HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

# HR_API_AUTH_MODE: "none" (local dev only) / "api_key" (static X-API-Key header) / "jwt" (Bearer
# JWT, HS256). Airbyte's hr_api.yaml source config must be set to match - see the comment there.
AUTH_MODE = os.environ.get("HR_API_AUTH_MODE", "none")

_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
_bearer_scheme = HTTPBearer(auto_error=False)


def require_auth(
    api_key: Optional[str] = Security(_api_key_header),
    bearer: Optional[HTTPAuthorizationCredentials] = Security(_bearer_scheme),
) -> None:
    if AUTH_MODE == "none":
        return
    if AUTH_MODE == "api_key":
        if api_key != os.environ["HR_API_KEY"]:
            raise HTTPException(status_code=401, detail="Invalid or missing X-API-Key header")
        return
    if AUTH_MODE == "jwt":
        if bearer is None:
            raise HTTPException(status_code=401, detail="Missing Authorization: Bearer <token> header")
        try:
            jwt.decode(bearer.credentials, os.environ["HR_API_JWT_SECRET"], algorithms=["HS256"])
        except jwt.PyJWTError:
            raise HTTPException(status_code=401, detail="Invalid or expired JWT")
        return
    raise RuntimeError(f"Unknown HR_API_AUTH_MODE: {AUTH_MODE!r}")


app = FastAPI(
    title="HR / Partner Registry API (Static/Mock)",
    description=(
        "Placeholder registry covering both Moi gioi/quan ly (nhan vien chinh thuc, co employee_code) "
        "and CTV (cong tac vien ben ngoai, khong co employee_code). Replace with the real HR/partner "
        "system integration - the id_number (CCCD) field is the mapping key that works for both."
    ),
    version="0.2.0",
    dependencies=[Depends(require_auth)],
)


class Person(BaseModel):
    id_number: str  # CCCD - universal key: present for BOTH EMPLOYEE (MG/quan ly) and COLLABORATOR (CTV)
    employee_code: Optional[str] = None  # HR employee code - only set when person_type == EMPLOYEE
    full_name: str
    person_type: str  # EMPLOYEE (Moi gioi/Truong phong/Giam doc) / COLLABORATOR (CTV ben ngoai)
    branch_code: str
    branch_name: str
    department_code: Optional[str] = None  # NULL for branch-level roles (e.g. Giam doc chi nhanh)
    department_name: Optional[str] = None
    position: str        # ten chuc danh de hien thi
    position_code: str   # ma chuc danh - dung chung voi raw.broker.broker_subtype ben Database khi co the
    position_level: str  # BROKER / HEAD_OF_DEPARTMENT / BRANCH_DIRECTOR / COLLABORATOR
    manager_employee_code: Optional[str] = None  # employee_code of the direct manager (EMPLOYEE only)
    start_date: str
    end_date: Optional[str] = None
    status: str


# Keyed by id_number (CCCD) - the universal key, unlike employee_code which CTV don't have.
# id_number values here match Database/Common/09_seed_sample_data.sql's broker.id_number 1:1, so
# that small example dataset demonstrates full end-to-end HR/partner mapping. The at-scale
# generator (Database/Common/10_seed_at_scale.sql) creates 300 brokers/CTV with randomly-generated
# id_number that will NOT be found here - a real HR/partner system would carry the full roster,
# this mock only covers the illustrative example set.
_PERSONS: dict[str, Person] = {
    "001099000001": Person(
        id_number="001099000001",
        employee_code="NV0001",
        full_name="Nguyen Van A",
        person_type="EMPLOYEE",
        branch_code="CN01",
        branch_name="Chi nhanh Ha Noi",
        department_code="PB01",
        department_name="Phong Moi Gioi Ha Noi",
        position="Chuyen vien Moi gioi",
        position_code="STANDARD",
        position_level="BROKER",
        manager_employee_code="NV0003",
        start_date="2021-03-01",
        status="ACTIVE",
    ),
    "079099000002": Person(
        id_number="079099000002",
        employee_code="NV0002",
        full_name="Tran Thi B",
        person_type="EMPLOYEE",
        branch_code="CN02",
        branch_name="Chi nhanh TP.HCM",
        department_code="PB02",
        department_name="Phong Moi Gioi TP.HCM",
        position="Chuyen vien Moi gioi cao cap",
        position_code="SENIOR",
        position_level="BROKER",
        manager_employee_code=None,
        start_date="2019-07-15",
        status="ACTIVE",
    ),
    "001099000099": Person(
        id_number="001099000099",
        employee_code=None,
        full_name="Le Van C",
        person_type="COLLABORATOR",
        branch_code="CN01",
        branch_name="Chi nhanh Ha Noi",
        department_code="PB01",
        department_name="Phong Moi Gioi Ha Noi",
        position="Cong tac vien gioi thieu",
        position_code="REFERRAL_INDIVIDUAL",
        position_level="COLLABORATOR",
        manager_employee_code=None,
        start_date="2023-01-10",
        status="ACTIVE",
    ),
    "001099000003": Person(
        id_number="001099000003",
        employee_code="NV0003",
        full_name="Do Van F",
        person_type="EMPLOYEE",
        branch_code="CN01",
        branch_name="Chi nhanh Ha Noi",
        department_code="PB01",
        department_name="Phong Moi Gioi Ha Noi",
        position="Truong phong Moi gioi",
        position_code="HEAD_OF_DEPARTMENT",
        position_level="HEAD_OF_DEPARTMENT",
        manager_employee_code="NV0004",
        start_date="2017-02-01",
        status="ACTIVE",
    ),
    "001099000004": Person(
        id_number="001099000004",
        employee_code="NV0004",
        full_name="Hoang Thi G",
        person_type="EMPLOYEE",
        branch_code="CN01",
        branch_name="Chi nhanh Ha Noi",
        department_code=None,  # Giam doc chi nhanh phu trach ca chi nhanh, khong thuoc 1 phong ban cu the
        department_name=None,
        position="Giam doc chi nhanh",
        position_code="BRANCH_DIRECTOR",
        position_level="BRANCH_DIRECTOR",
        manager_employee_code=None,
        start_date="2015-06-01",
        status="ACTIVE",
    ),
}


def _find_by_employee_code(employee_code: str) -> Optional[Person]:
    return next((p for p in _PERSONS.values() if p.employee_code == employee_code), None)


@app.get("/employees", response_model=list[Person])
def list_employees(status: Optional[str] = None, person_type: Optional[str] = None):
    persons = list(_PERSONS.values())
    if status is not None:
        persons = [p for p in persons if p.status == status]
    if person_type is not None:
        persons = [p for p in persons if p.person_type == person_type]
    return persons


@app.get("/employees/{id_number}", response_model=Person)
def get_employee(id_number: str):
    person = _PERSONS.get(id_number)
    if person is None:
        raise HTTPException(status_code=404, detail="Person not found")
    return person


@app.get("/employees/{id_number}/manager-chain", response_model=list[Person])
def get_manager_chain(id_number: str):
    """Walks manager_employee_code up to the top - used by ETL to roll up management-override commission.
    Only EMPLOYEE rows participate in this chain (COLLABORATOR/CTV have no manager_employee_code)."""
    person = _PERSONS.get(id_number)
    if person is None:
        raise HTTPException(status_code=404, detail="Person not found")

    chain: list[Person] = []
    current_code = person.manager_employee_code
    visited = {id_number}
    while current_code is not None:
        manager = _find_by_employee_code(current_code)
        if manager is None or manager.id_number in visited:
            break
        chain.append(manager)
        visited.add(manager.id_number)
        current_code = manager.manager_employee_code
    return chain
