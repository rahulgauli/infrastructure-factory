from fastapi import APIRouter, HTTPException

from app.models.infrastructure import CloudProvider, ResourceType

router = APIRouter(prefix="/api/v1/providers", tags=["providers"])

SUPPORTED_PROVIDER_RESOURCES: dict[CloudProvider, list[ResourceType]] = {
    CloudProvider.AWS: [
        ResourceType.VPC,
        ResourceType.EC2,
        ResourceType.S3,
        ResourceType.RDS,
        ResourceType.EKS,
    ],
    CloudProvider.GCP: [
        ResourceType.VPC,
        ResourceType.GKE,
        ResourceType.STORAGE,
    ],
    CloudProvider.AZURE: [
        ResourceType.VNET,
        ResourceType.AKS,
        ResourceType.STORAGE,
    ],
}


def get_supported_resources(provider: CloudProvider) -> list[ResourceType]:
    return SUPPORTED_PROVIDER_RESOURCES[provider]


@router.get("/")
def list_providers() -> dict[str, list[dict[str, object]]]:
    return {
        "providers": [
            {
                "provider": provider.value,
                "resources": [resource.value for resource in resources],
            }
            for provider, resources in SUPPORTED_PROVIDER_RESOURCES.items()
        ]
    }


@router.get("/{provider}")
def get_provider(provider: str) -> dict[str, object]:
    try:
        cloud_provider = CloudProvider(provider)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=f"Provider '{provider}' is not supported") from exc

    resources = SUPPORTED_PROVIDER_RESOURCES[cloud_provider]
    return {
        "provider": cloud_provider.value,
        "resource_count": len(resources),
        "resources": [resource.value for resource in resources],
    }
