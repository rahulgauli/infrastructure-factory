# Copilot Instructions — Infrastructure Factory

## Project Purpose

Infrastructure Factory is a **FastAPI service** that generates opinionated, enterprise-grade Terraform stacks for AWS, GCP, and Azure. It is designed for platform teams that need self-service infrastructure provisioning while guaranteeing every stack inherits centralized security controls.

---

## Repository Layout

```
app/
  api/routes/              FastAPI routers (infrastructure, providers)
  core/config.py           pydantic-settings application configuration
  models/infrastructure.py Pydantic request/response models and enums
  services/
    terraform_generator.py Renders main.tf, variables.tf, terraform.tfvars.json
    terraform_executor.py  Async wrapper around the terraform CLI (init/plan/apply/destroy)
terraform/modules/
  aws/{vpc,ec2,s3,rds,eks}/   AWS provider modules
  gcp/{vpc,gke,storage}/      GCP provider modules
  azure/{vnet,aks,storage}/   Azure provider modules
  security/{aws,gcp,azure}/   Provider security-baseline modules
policies/terraform/
  aws.rego                 OPA Rego policies for AWS Terraform resources
  gcp.rego                 OPA Rego policies for GCP Terraform resources
  azure.rego               OPA Rego policies for Azure Terraform resources
tests/
  test_infrastructure_api.py  API integration tests
  test_terraform_generator.py Unit tests for TerraformGenerator
.github/workflows/
  pr-security-scan.yml     SCA (Trivy), SAST (Bandit + Semgrep), IaC (Checkov) scan
  terraform-policy.yml     OPA/conftest Rego policy validation on Terraform files
```

---

## Architecture

The request lifecycle flows as follows:

1. **REST API** (`POST /api/v1/infrastructure/`) receives an `InfrastructureRequest`.
2. `TerraformGenerator` renders `main.tf`, `variables.tf`, and `terraform.tfvars.json` into `generated/<team>/<id>/`.
3. When `enable_security_baseline=true`, a provider-specific security module is injected before any workload modules.
4. Subsequent plan/apply/destroy calls delegate to `TerraformExecutor`, which shells out to the `terraform` CLI via `asyncio.create_subprocess_exec`.
5. An in-memory `INFRASTRUCTURE_STORE` dict tracks all request records (not persisted across restarts).
6. A `Semaphore(max_concurrent_executions)` caps concurrent Terraform operations.

---

## Coding Conventions

### Python
- **Python 3.12+**; use built-in generics (`list[str]`, `dict[str, str]`) rather than `typing.List`/`typing.Dict`.
- All models are **Pydantic v2** (`BaseModel`, `Field`). Do not use `pydantic.v1`.
- Configuration is loaded via `pydantic-settings` (`BaseSettings`); expose settings through `get_settings()` (LRU-cached).
- Use **FastAPI** `APIRouter` with explicit `prefix` and `tags`; do not register routes directly on the `app` object.
- Async route handlers are reserved for operations that perform I/O (i.e., Terraform CLI calls). Simple CRUD routes are synchronous.
- Raise `HTTPException` for client errors; never let internal exceptions propagate to the HTTP response.
- Output directory paths for `TerraformGenerator` **must** be relative and must not contain `..` components (enforced in `_resolve_output_dir`).

### Terraform Modules
- Every module directory must contain `main.tf`, `variables.tf`, and `outputs.tf`.
- Variable names must match those used in the generated `main.tf`: `team_name`, `environment`, `region`, `tags`.
- Azure modules additionally require `location` (alias for `region`) and `resource_group_name`.
- GCP modules additionally require `project_id`.
- Security baseline modules live under `terraform/modules/security/<provider>/` and are always rendered first.

### Rego Policies (`policies/terraform/`)
- Package names must follow the pattern `terraform.<provider>` (e.g., `terraform.aws`).
- Use `deny[msg]` for hard failures and `warn[msg]` for advisories.
- Policies are evaluated by `conftest` with `--parser hcl2 --all-namespaces`.
- When adding a new resource type, add corresponding `deny`/`warn` rules to the relevant `.rego` file.

---

## Adding a New Cloud Provider

1. Add the provider value to the `CloudProvider` enum in `app/models/infrastructure.py`.
2. Add supported resource types to `SUPPORTED_PROVIDER_RESOURCES` in `app/api/routes/providers.py`.
3. Add enum members to `ResourceType` in `app/models/infrastructure.py` if new resource types are needed.
4. Extend `TerraformGenerator` with:
   - A new branch in `_terraform_block()` for provider configuration.
   - A new branch in `_locals_block()` if the provider needs computed locals.
   - A new branch in `_security_module_block()` pointing to `../../terraform/modules/security/<provider>`.
   - A new branch in `_resource_module_block()` for module source paths and input variables.
5. Create Terraform modules under `terraform/modules/<provider>/` and `terraform/modules/security/<provider>/`.
6. Create Rego policies in `policies/terraform/<provider>.rego` following the `terraform.<provider>` package convention.
7. Add tests in `tests/test_infrastructure_api.py` and `tests/test_terraform_generator.py`.

---

## Adding a New Resource Type to an Existing Provider

1. Add the resource to the `ResourceType` enum in `app/models/infrastructure.py`.
2. Append the resource to the provider's list in `SUPPORTED_PROVIDER_RESOURCES`.
3. Create a Terraform module under `terraform/modules/<provider>/<resource>/`.
4. Add `deny`/`warn` rules to the provider's `.rego` file in `policies/terraform/`.
5. Add generator tests asserting the correct module block is rendered.

---

## Security Requirements

- Every generated stack that sets `enable_security_baseline=true` must include the security baseline module for the targeted provider.
- Output directories are always resolved relative to the repository workspace root; absolute paths and `..` traversals are rejected.
- Terraform execution is guarded by a semaphore (`MAX_CONCURRENT_EXECUTIONS`, default 5).
- The `pr-security-scan` workflow runs on every PR targeting `main`/`master` and reports SCA (Trivy), SAST (Bandit + Semgrep), and IaC (Checkov) findings as PR comments.
- The `terraform-policy` workflow validates all `.tf` files in `terraform/` against the Rego policies in `policies/terraform/` on every PR.

---

## Testing

Run tests with:

```bash
pip install -r requirements.txt
python -m pytest tests/ -v
```

- Tests use `httpx.AsyncClient` with `ASGITransport` for API integration tests.
- Generator tests assert that rendered HCL output contains expected Terraform blocks.
- Do not remove or weaken existing test assertions; add new tests whenever you add functionality.
- Mark async tests with `@pytest.mark.asyncio`.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `Infrastructure Factory` | FastAPI application title |
| `APP_VERSION` | `1.0.0` | API version |
| `DEBUG` | `False` | Enable FastAPI debug mode |
| `GENERATED_DIR` | `generated` | Root directory for generated Terraform stacks |
| `TERRAFORM_BIN` | `terraform` | Path to the Terraform CLI binary |
| `MAX_CONCURRENT_EXECUTIONS` | `5` | Semaphore limit for concurrent Terraform operations |

---

## Common Pitfalls

- `INFRASTRUCTURE_STORE` is in-memory and resets on each application restart. Do not rely on it for persistence in new features without first adding a persistent backend.
- `TerraformExecutor` merges `stdout` and `stderr` into a single stream (`STDOUT`). Downstream parsing should not assume structured output.
- GCP provider blocks reference `local.gcp_project_id` which is derived from `team_name` and `environment`; ensure the locals block is always emitted before the provider block.
- Azure modules use both `region` and `location` (they are the same value); keep both variables when adding new Azure modules.
