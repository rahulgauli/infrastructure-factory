from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class CloudProvider(str, Enum):
    AWS = "aws"
    GCP = "gcp"
    AZURE = "azure"


class Environment(str, Enum):
    DEV = "dev"
    STAGING = "staging"
    PROD = "prod"


class ResourceType(str, Enum):
    VPC = "vpc"
    EC2 = "ec2"
    S3 = "s3"
    RDS = "rds"
    EKS = "eks"
    SQS = "sqs"
    GKE = "gke"
    STORAGE = "storage"
    VNET = "vnet"
    AKS = "aks"


class InfrastructureStatus(str, Enum):
    PENDING = "pending"
    GENERATED = "generated"
    PLANNED = "planned"
    APPLIED = "applied"
    FAILED = "failed"


class InfrastructureRequest(BaseModel):
    team_name: str
    cloud_provider: CloudProvider
    environment: Environment
    region: str
    resources: list[ResourceType]
    tags: dict[str, str] = Field(default_factory=dict)
    enable_security_baseline: bool = True


class InfrastructureResponse(BaseModel):
    id: str
    team_name: str
    cloud_provider: str
    environment: str
    status: str
    generated_path: str | None = None
    plan_output: str | None = None
    created_at: datetime
    updated_at: datetime
