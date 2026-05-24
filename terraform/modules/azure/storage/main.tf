locals {
  account_name = substr(regexreplace(lower("${var.team_name}${var.environment}storage"), "[^a-z0-9]", ""), 0, 24)
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

resource "azurerm_storage_account" "this" {
  name                            = local.account_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }

    versioning_enabled = true
  }
}
