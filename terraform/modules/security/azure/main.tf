data "azurerm_client_config" "current" {}

locals {
  name_prefix               = substr(regexreplace(lower("${var.team_name}-${var.environment}"), "[^a-z0-9-]", "-"), 0, 20)
  effective_subscription_id = var.subscription_id != "" ? var.subscription_id : data.azurerm_client_config.current.subscription_id
  tags = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
    security    = "baseline"
  })
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.name_prefix}-sec-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_security_center_subscription_pricing" "defender" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_key_vault" "this" {
  name                       = substr(regexreplace(lower("${var.team_name}${var.environment}kv"), "[^a-z0-9]", ""), 0, 24)
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  tags                       = local.tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions    = ["Get", "List", "Create"]
    secret_permissions = ["Get", "List", "Set"]
  }
}

resource "azurerm_monitor_diagnostic_setting" "platform_logs" {
  name                       = "${local.name_prefix}-diag"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_policy_definition" "cis_baseline" {
  name         = "${local.name_prefix}-cis-baseline"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Infrastructure Factory CIS Baseline"

  metadata = jsonencode({
    category = "Security Center"
  })

  policy_rule = jsonencode({
    if = {
      field  = "type"
      equals = "Microsoft.Storage/storageAccounts"
    }
    then = {
      effect = "audit"
    }
  })
}

resource "azurerm_policy_assignment" "cis_baseline" {
  name                 = "${local.name_prefix}-cis-assignment"
  scope                = "/subscriptions/${local.effective_subscription_id}"
  policy_definition_id = azurerm_policy_definition.cis_baseline.id
  display_name         = "Infrastructure Factory CIS Baseline"
}
