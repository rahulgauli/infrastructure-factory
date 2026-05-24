import json
from pathlib import Path
from textwrap import dedent

from app.models.infrastructure import CloudProvider, InfrastructureRequest, ResourceType


class TerraformGenerator:
    def generate(self, request: InfrastructureRequest, output_dir: str) -> str:
        target_dir = self._resolve_output_dir(output_dir)
        target_dir.mkdir(parents=True, exist_ok=True)

        (target_dir / "main.tf").write_text(self._render_main_tf(request), encoding="utf-8")
        (target_dir / "variables.tf").write_text(self._render_variables_tf(), encoding="utf-8")
        (target_dir / "terraform.tfvars.json").write_text(
            json.dumps(
                {
                    "team_name": request.team_name,
                    "environment": request.environment.value,
                    "region": request.region,
                    "tags": request.tags,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        return str(target_dir)

    def _resolve_output_dir(self, output_dir: str) -> Path:
        raw_path = Path(output_dir)
        if raw_path.is_absolute():
            raise ValueError("Output directory must be a relative path inside the repository workspace")
        if any(part == ".." for part in raw_path.parts):
            raise ValueError("Output directory cannot escape the repository workspace")

        workspace_root = Path.cwd().resolve()
        return workspace_root.joinpath(raw_path).resolve()

    def _render_main_tf(self, request: InfrastructureRequest) -> str:
        provider = request.cloud_provider
        blocks = [self._terraform_block(provider), self._locals_block(provider)]

        if request.enable_security_baseline:
            blocks.append(self._security_module_block(provider))

        for resource in request.resources:
            blocks.append(self._resource_module_block(provider, resource))

        return "\n\n".join(blocks) + "\n"

    def _render_variables_tf(self) -> str:
        return dedent(
            '''
            variable "team_name" {
              description = "Owning team for the generated infrastructure"
              type        = string
            }

            variable "environment" {
              description = "Deployment environment"
              type        = string
            }

            variable "region" {
              description = "Primary cloud region or location"
              type        = string
            }

            variable "tags" {
              description = "Common labels/tags applied to cloud resources"
              type        = map(string)
              default     = {}
            }
            '''
        ).lstrip()

    def _terraform_block(self, provider: CloudProvider) -> str:
        if provider == CloudProvider.AWS:
            return dedent(
                '''
                terraform {
                  required_version = ">= 1.5.0"

                  required_providers {
                    aws = {
                      source  = "hashicorp/aws"
                      version = "~> 5.0"
                    }
                  }
                }

                provider "aws" {
                  region = var.region

                  default_tags {
                    tags = merge(var.tags, {
                      team_name   = var.team_name
                      environment = var.environment
                      managed_by  = "infrastructure-factory"
                    })
                  }
                }
                '''
            ).lstrip()
        if provider == CloudProvider.GCP:
            return dedent(
                '''
                terraform {
                  required_version = ">= 1.5.0"

                  required_providers {
                    google = {
                      source  = "hashicorp/google"
                      version = "~> 5.0"
                    }
                  }
                }

                provider "google" {
                  project = local.gcp_project_id
                  region  = var.region
                }
                '''
            ).lstrip()
        return dedent(
            '''
            terraform {
              required_version = ">= 1.5.0"

              required_providers {
                azurerm = {
                  source  = "hashicorp/azurerm"
                  version = "~> 3.0"
                }
              }
            }

            provider "azurerm" {
              features {}
            }
            '''
        ).lstrip()

    def _locals_block(self, provider: CloudProvider) -> str:
        if provider == CloudProvider.GCP:
            return dedent(
                '''
                locals {
                  name_prefix    = lower("${var.team_name}-${var.environment}")
                  gcp_project_id = substr(regexreplace(local.name_prefix, "[^a-z0-9-]", "-"), 0, 30)
                }
                '''
            ).lstrip()
        if provider == CloudProvider.AZURE:
            return dedent(
                '''
                locals {
                  name_prefix               = lower("${var.team_name}-${var.environment}")
                  azure_resource_group_name = substr(regexreplace("rg-${local.name_prefix}", "[^a-z0-9-]", "-"), 0, 90)
                }
                '''
            ).lstrip()
        return dedent(
            '''
            locals {
              name_prefix = lower("${var.team_name}-${var.environment}")
            }
            '''
        ).lstrip()

    def _security_module_block(self, provider: CloudProvider) -> str:
        if provider == CloudProvider.AWS:
            return dedent(
                '''
                module "security_baseline" {
                  source      = "../../terraform/modules/security/aws"
                  team_name   = var.team_name
                  environment = var.environment
                  region      = var.region
                  tags        = var.tags
                }
                '''
            ).lstrip()
        if provider == CloudProvider.GCP:
            return dedent(
                '''
                module "security_baseline" {
                  source      = "../../terraform/modules/security/gcp"
                  project_id  = local.gcp_project_id
                  team_name   = var.team_name
                  environment = var.environment
                  region      = var.region
                  tags        = var.tags
                }
                '''
            ).lstrip()
        return dedent(
            '''
            module "security_baseline" {
              source              = "../../terraform/modules/security/azure"
              resource_group_name = local.azure_resource_group_name
              team_name           = var.team_name
              environment         = var.environment
              location            = var.region
              region              = var.region
              tags                = var.tags
            }
            '''
        ).lstrip()

    def _resource_module_block(self, provider: CloudProvider, resource: ResourceType) -> str:
        if provider == CloudProvider.AWS:
            return dedent(
                f'''
                module "{resource.value}" {{
                  source      = "../../terraform/modules/aws/{resource.value}"
                  team_name   = var.team_name
                  environment = var.environment
                  region      = var.region
                  tags        = var.tags
                }}
                '''
            ).lstrip()
        if provider == CloudProvider.GCP:
            return dedent(
                f'''
                module "{resource.value}" {{
                  source      = "../../terraform/modules/gcp/{resource.value}"
                  project_id  = local.gcp_project_id
                  team_name   = var.team_name
                  environment = var.environment
                  region      = var.region
                  tags        = var.tags
                }}
                '''
            ).lstrip()
        return dedent(
            f'''
            module "{resource.value}" {{
              source              = "../../terraform/modules/azure/{resource.value}"
              resource_group_name = local.azure_resource_group_name
              team_name           = var.team_name
              environment         = var.environment
              region              = var.region
              location            = var.region
              tags                = var.tags
            }}
            '''
        ).lstrip()
