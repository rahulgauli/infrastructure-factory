import shutil
from pathlib import Path
from uuid import uuid4

from app.models.infrastructure import CloudProvider, Environment, InfrastructureRequest, ResourceType
from app.services.terraform_generator import TerraformGenerator


ARTIFACT_ROOT = Path("generated") / "test-artifacts"


def build_request(enable_security_baseline: bool = True) -> InfrastructureRequest:
    return InfrastructureRequest(
        team_name="platform",
        cloud_provider=CloudProvider.AWS,
        environment=Environment.DEV,
        region="us-east-1",
        resources=[ResourceType.VPC, ResourceType.S3],
        tags={"owner": "platform"},
        enable_security_baseline=enable_security_baseline,
    )


def test_generate_writes_expected_files() -> None:
    generator = TerraformGenerator()
    output_dir = ARTIFACT_ROOT / f"generator-{uuid4().hex}"

    try:
        generated_path = Path(generator.generate(build_request(), str(output_dir)))
        assert generated_path.exists()
        assert (generated_path / "main.tf").exists()
        assert (generated_path / "variables.tf").exists()
        assert (generated_path / "terraform.tfvars.json").exists()
    finally:
        shutil.rmtree(output_dir, ignore_errors=True)


def test_generate_includes_security_module_when_enabled() -> None:
    generator = TerraformGenerator()
    output_dir = ARTIFACT_ROOT / f"generator-{uuid4().hex}"

    try:
        generated_path = Path(generator.generate(build_request(enable_security_baseline=True), str(output_dir)))
        main_tf = (generated_path / "main.tf").read_text(encoding="utf-8")
        assert 'module "security_baseline"' in main_tf
        assert '../../terraform/modules/security/aws' in main_tf
    finally:
        shutil.rmtree(output_dir, ignore_errors=True)


def test_generate_omits_security_module_when_disabled() -> None:
    generator = TerraformGenerator()
    output_dir = ARTIFACT_ROOT / f"generator-{uuid4().hex}"

    try:
        generated_path = Path(generator.generate(build_request(enable_security_baseline=False), str(output_dir)))
        main_tf = (generated_path / "main.tf").read_text(encoding="utf-8")
        assert 'module "security_baseline"' not in main_tf
    finally:
        shutil.rmtree(output_dir, ignore_errors=True)


def test_generate_references_requested_resource_modules() -> None:
    generator = TerraformGenerator()
    output_dir = ARTIFACT_ROOT / f"generator-{uuid4().hex}"

    try:
        generated_path = Path(generator.generate(build_request(), str(output_dir)))
        main_tf = (generated_path / "main.tf").read_text(encoding="utf-8")
        assert '../../terraform/modules/aws/vpc' in main_tf
        assert '../../terraform/modules/aws/s3' in main_tf
    finally:
        shutil.rmtree(output_dir, ignore_errors=True)


def build_sqs_request() -> InfrastructureRequest:
    return InfrastructureRequest(
        team_name="platform",
        cloud_provider=CloudProvider.AWS,
        environment=Environment.DEV,
        region="us-east-1",
        resources=[ResourceType.SQS],
        tags={"owner": "platform"},
        enable_security_baseline=True,
    )


def test_generate_includes_sqs_module_block() -> None:
    generator = TerraformGenerator()
    output_dir = ARTIFACT_ROOT / f"generator-{uuid4().hex}"

    try:
        generated_path = Path(generator.generate(build_sqs_request(), str(output_dir)))
        main_tf = (generated_path / "main.tf").read_text(encoding="utf-8")
        assert 'module "sqs"' in main_tf
        assert '../../terraform/modules/aws/sqs' in main_tf
    finally:
        shutil.rmtree(output_dir, ignore_errors=True)


def test_generate_sqs_includes_standard_variables() -> None:
    generator = TerraformGenerator()
    output_dir = ARTIFACT_ROOT / f"generator-{uuid4().hex}"

    try:
        generated_path = Path(generator.generate(build_sqs_request(), str(output_dir)))
        main_tf = (generated_path / "main.tf").read_text(encoding="utf-8")
        assert 'team_name   = var.team_name' in main_tf
        assert 'environment = var.environment' in main_tf
        assert 'region      = var.region' in main_tf
        assert 'tags        = var.tags' in main_tf
    finally:
        shutil.rmtree(output_dir, ignore_errors=True)
