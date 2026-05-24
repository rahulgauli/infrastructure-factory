import asyncio
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, HTTPException, status

from app.api.routes.providers import get_supported_resources
from app.core.config import get_settings
from app.models.infrastructure import (
    CloudProvider,
    InfrastructureRequest,
    InfrastructureResponse,
    InfrastructureStatus,
)
from app.services.terraform_executor import TerraformExecutor
from app.services.terraform_generator import TerraformGenerator

router = APIRouter(prefix="/api/v1/infrastructure", tags=["infrastructure"])
settings = get_settings()
generator = TerraformGenerator()
executor = TerraformExecutor()
execution_semaphore = asyncio.Semaphore(settings.max_concurrent_executions)


@dataclass
class InfrastructureRecord:
    request: InfrastructureRequest
    response: InfrastructureResponse


INFRASTRUCTURE_STORE: dict[str, InfrastructureRecord] = {}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _get_record(infrastructure_id: str) -> InfrastructureRecord:
    record = INFRASTRUCTURE_STORE.get(infrastructure_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Infrastructure entry not found")
    return record


def _validate_resources(cloud_provider: CloudProvider, resources: list) -> None:
    supported = set(get_supported_resources(cloud_provider))
    invalid = [resource.value for resource in resources if resource not in supported]
    if invalid:
        raise HTTPException(
            status_code=400,
            detail={
                "message": f"Unsupported resources for provider '{cloud_provider.value}'",
                "invalid_resources": invalid,
            },
        )


@router.post("/", response_model=InfrastructureResponse, status_code=status.HTTP_201_CREATED)
def create_infrastructure(request: InfrastructureRequest) -> InfrastructureResponse:
    _validate_resources(request.cloud_provider, request.resources)

    infrastructure_id = str(uuid4())
    created_at = _utcnow()
    safe_team = request.team_name.lower().replace(" ", "-")
    output_dir = Path(settings.generated_dir) / safe_team / infrastructure_id
    generated_path = generator.generate(request, str(output_dir))

    response = InfrastructureResponse(
        id=infrastructure_id,
        team_name=request.team_name,
        cloud_provider=request.cloud_provider.value,
        environment=request.environment.value,
        status=InfrastructureStatus.GENERATED.value,
        generated_path=generated_path,
        created_at=created_at,
        updated_at=created_at,
    )
    INFRASTRUCTURE_STORE[infrastructure_id] = InfrastructureRecord(request=request, response=response)
    return response


@router.get("/", response_model=list[InfrastructureResponse])
def list_infrastructure() -> list[InfrastructureResponse]:
    return [record.response for record in INFRASTRUCTURE_STORE.values()]


@router.get("/{infrastructure_id}", response_model=InfrastructureResponse)
def get_infrastructure(infrastructure_id: str) -> InfrastructureResponse:
    return _get_record(infrastructure_id).response


@router.post("/{infrastructure_id}/plan", response_model=InfrastructureResponse)
async def plan_infrastructure(infrastructure_id: str) -> InfrastructureResponse:
    record = _get_record(infrastructure_id)

    async with execution_semaphore:
        init_code, init_output = await executor.init(record.response.generated_path or "")
        if init_code != 0:
            record.response.status = InfrastructureStatus.FAILED.value
            record.response.plan_output = init_output
            record.response.updated_at = _utcnow()
            return record.response

        plan_code, plan_output = await executor.plan(record.response.generated_path or "")

    record.response.status = (
        InfrastructureStatus.PLANNED.value if plan_code == 0 else InfrastructureStatus.FAILED.value
    )
    record.response.plan_output = f"{init_output}\n{plan_output}".strip()
    record.response.updated_at = _utcnow()
    return record.response


@router.post("/{infrastructure_id}/apply", response_model=InfrastructureResponse)
async def apply_infrastructure(infrastructure_id: str) -> InfrastructureResponse:
    record = _get_record(infrastructure_id)

    async with execution_semaphore:
        init_code, init_output = await executor.init(record.response.generated_path or "")
        if init_code != 0:
            record.response.status = InfrastructureStatus.FAILED.value
            record.response.plan_output = init_output
            record.response.updated_at = _utcnow()
            return record.response

        apply_code, apply_output = await executor.apply(record.response.generated_path or "")

    record.response.status = (
        InfrastructureStatus.APPLIED.value if apply_code == 0 else InfrastructureStatus.FAILED.value
    )
    record.response.plan_output = f"{init_output}\n{apply_output}".strip()
    record.response.updated_at = _utcnow()
    return record.response


@router.delete("/{infrastructure_id}")
async def delete_infrastructure(infrastructure_id: str) -> dict[str, str]:
    record = _get_record(infrastructure_id)

    if record.response.generated_path and Path(record.response.generated_path).exists():
        async with execution_semaphore:
            destroy_code, destroy_output = await executor.destroy(record.response.generated_path)
        if destroy_code != 0:
            record.response.status = InfrastructureStatus.FAILED.value
            record.response.plan_output = destroy_output
            record.response.updated_at = _utcnow()
            raise HTTPException(status_code=500, detail="Terraform destroy failed")
        shutil.rmtree(record.response.generated_path, ignore_errors=True)

    INFRASTRUCTURE_STORE.pop(infrastructure_id, None)
    return {"id": infrastructure_id, "status": "deleted"}
