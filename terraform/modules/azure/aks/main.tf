locals {
  name_prefix = substr(regexreplace(lower("${var.team_name}-${var.environment}"), "[^a-z0-9-]", "-"), 0, 30)
  tags = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
  })
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${local.name_prefix}-aks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "${local.name_prefix}-dns"
  kubernetes_version  = var.kubernetes_version
  tags                = local.tags

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    node_count           = 1
    enable_auto_scaling  = true
    min_count            = 1
    max_count            = 3
    orchestrator_version = var.kubernetes_version
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }
}
