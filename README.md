# Infrastructure Factory

Infrastructure Factory is a FastAPI service that generates opinionated Terraform stacks for AWS, GCP, and Azure. It is designed for enterprise platform teams that need self-service infrastructure generation while guaranteeing that every stack inherits centralized security controls.

## Architecture

```text
                    +-----------------------------+
                    |  Consumers / Platform Teams |
                    +--------------+--------------+
                                   |
                                   | REST API
                                   v
+-------------------+    +---------+----------+    +------------------------+
| Provider Catalog  |<-->| FastAPI Application |<-->| In-memory State Store |
+-------------------+    |  - request models   |    +------------------------+
                         |  - generation routes |
                         |  - provider routes   |
                         +---------+------------+
                                   |
                                   | render Terraform
                                   v
                         +---------+------------+
                         | Generated Terraform   |
                         |  - provider modules   |
                         |  - security baseline  |
                         +---------+------------+
                                   |
                                   | terraform init/plan/apply/destroy
                                   v
                         +---------+------------+
                         | Cloud Provider APIs   |
                         +-----------------------+
```

## Features

- FastAPI service for infrastructure generation and execution workflows.
- Supports AWS, GCP, and Azure from a single API surface.
- Automatically injects provider-specific security baseline modules for enterprise controls.
- Stores generated Terraform per request under `generated/<team>/<id>`.
- Includes async Terraform execution helpers for `init`, `plan`, `apply`, and `destroy`.
- Ships with Docker and Docker Compose for local development.
- Includes tests for the API and Terraform generator.

## Supported Providers and Resource Types

| Provider | Resource Types |
| --- | --- |
| AWS | `vpc`, `ec2`, `s3`, `rds`, `eks` |
| GCP | `vpc`, `gke`, `storage` |
| Azure | `vnet`, `aks`, `storage` |

## API Reference

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/health` | Health check endpoint |
| `GET` | `/api/v1/providers/` | List supported providers and resource types |
| `GET` | `/api/v1/providers/{provider}` | Provider details |
| `POST` | `/api/v1/infrastructure/` | Create an infrastructure request and generate Terraform |
| `GET` | `/api/v1/infrastructure/` | List generated infrastructure requests |
| `GET` | `/api/v1/infrastructure/{id}` | Get one infrastructure request |
| `POST` | `/api/v1/infrastructure/{id}/plan` | Run `terraform plan` |
| `POST` | `/api/v1/infrastructure/{id}/apply` | Run `terraform apply` |
| `DELETE` | `/api/v1/infrastructure/{id}` | Run `terraform destroy` and remove the request |

### Example Request

```json
{
  "team_name": "platform-engineering",
  "cloud_provider": "aws",
  "environment": "dev",
  "region": "us-east-1",
  "resources": ["vpc", "s3", "eks"],
  "tags": {
    "cost_center": "platform",
    "owner": "cloud-team"
  },
  "enable_security_baseline": true
}
```

## Quick Start

### Run with Docker Compose

```bash
docker-compose up --build
```

The API will be available at `http://localhost:8000`.

### Run Locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Run Tests

```bash
python -m pytest tests/ -v
```

## How Security Baseline Injection Works

When `enable_security_baseline` is `true`, the Terraform generator always adds a provider-specific security module to the generated `main.tf`:

- AWS: `../../terraform/modules/security/aws`
- GCP: `../../terraform/modules/security/gcp`
- Azure: `../../terraform/modules/security/azure`

That baseline module is rendered before workload modules so that common security controls such as audit logging, IAM/policy guardrails, diagnostic settings, and key management are present in every generated stack.

## Adding a New Provider

1. Add the provider to `CloudProvider` in `app/models/infrastructure.py`.
2. Update `SUPPORTED_PROVIDER_RESOURCES` in `app/api/routes/providers.py`.
3. Extend `TerraformGenerator` with provider-specific `required_providers`, locals, and module rendering.
4. Add Terraform modules under `terraform/modules/<provider>/` and `terraform/modules/security/<provider>/`.
5. Add tests for provider discovery and generator output.
6. If execution behavior differs, update `TerraformExecutor` or route orchestration.

## Configuration Reference

Configuration is provided through environment variables and loaded with `pydantic-settings`.

| Variable | Default | Description |
| --- | --- | --- |
| `APP_NAME` | `Infrastructure Factory` | Application name exposed by FastAPI |
| `APP_VERSION` | `1.0.0` | API version |
| `DEBUG` | `False` | Enables FastAPI debug behavior |
| `GENERATED_DIR` | `generated` | Output folder for generated Terraform stacks |
| `TERRAFORM_BIN` | `terraform` | Path to the Terraform CLI binary |
| `MAX_CONCURRENT_EXECUTIONS` | `5` | Max concurrent Terraform execution operations |

## Repository Layout

```text
app/
  api/routes/              FastAPI routers
  core/config.py           Application settings
  models/infrastructure.py Request and response models
  services/                Terraform generation and execution
terraform/modules/         Provider and security Terraform modules
tests/                     API and generator tests
```
