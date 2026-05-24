from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi.testclient import TestClient

from app.api.routes.infrastructure import INFRASTRUCTURE_STORE
from app.main import app
from app.services.terraform_executor import TerraformExecutor
from app.services.terraform_generator import TerraformGenerator


@pytest.fixture(autouse=True)
def clear_store() -> None:
    INFRASTRUCTURE_STORE.clear()
    yield
    INFRASTRUCTURE_STORE.clear()


@pytest.fixture(autouse=True)
def mock_terraform(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(TerraformGenerator, "generate", lambda self, request, output_dir: output_dir)
    monkeypatch.setattr(TerraformExecutor, "init", AsyncMock(return_value=(0, "terraform init ok")))
    monkeypatch.setattr(TerraformExecutor, "plan", AsyncMock(return_value=(0, "terraform plan ok")))
    monkeypatch.setattr(TerraformExecutor, "apply", AsyncMock(return_value=(0, "terraform apply ok")))
    monkeypatch.setattr(TerraformExecutor, "destroy", AsyncMock(return_value=(0, "terraform destroy ok")))


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


def test_create_infrastructure(client: TestClient) -> None:
    payload = {
        "team_name": "platform",
        "cloud_provider": "aws",
        "environment": "dev",
        "region": "us-east-1",
        "resources": ["vpc", "s3"],
        "tags": {"cost_center": "eng"},
        "enable_security_baseline": True,
    }

    response = client.post("/api/v1/infrastructure/", json=payload)

    assert response.status_code == httpx.codes.CREATED
    body = response.json()
    assert body["team_name"] == payload["team_name"]
    assert body["cloud_provider"] == payload["cloud_provider"]
    assert body["environment"] == payload["environment"]
    assert body["status"] == "generated"
    assert body["generated_path"].endswith(body["id"])


def test_list_infrastructure(client: TestClient) -> None:
    create_response = client.post(
        "/api/v1/infrastructure/",
        json={
            "team_name": "platform",
            "cloud_provider": "aws",
            "environment": "dev",
            "region": "us-east-1",
            "resources": ["vpc"],
        },
    )
    assert create_response.status_code == httpx.codes.CREATED

    response = client.get("/api/v1/infrastructure/")

    assert response.status_code == httpx.codes.OK
    assert len(response.json()) == 1


def test_get_infrastructure_by_id(client: TestClient) -> None:
    create_response = client.post(
        "/api/v1/infrastructure/",
        json={
            "team_name": "platform",
            "cloud_provider": "aws",
            "environment": "dev",
            "region": "us-east-1",
            "resources": ["vpc"],
        },
    )
    infrastructure_id = create_response.json()["id"]

    response = client.get(f"/api/v1/infrastructure/{infrastructure_id}")

    assert response.status_code == httpx.codes.OK
    assert response.json()["id"] == infrastructure_id


def test_get_infrastructure_not_found(client: TestClient) -> None:
    response = client.get("/api/v1/infrastructure/nonexistent")

    assert response.status_code == httpx.codes.NOT_FOUND


def test_list_providers(client: TestClient) -> None:
    response = client.get("/api/v1/providers/")

    assert response.status_code == httpx.codes.OK
    providers = {provider["provider"] for provider in response.json()["providers"]}
    assert providers == {"aws", "gcp", "azure"}


def test_health(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == httpx.codes.OK
    assert response.json() == {"status": "ok"}
