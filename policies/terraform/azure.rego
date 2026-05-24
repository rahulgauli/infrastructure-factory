package terraform.azure

# ── Azure Storage Account ─────────────────────────────────────────────────────

deny[msg] {
	sa := input.resource.azurerm_storage_account[name]
	sa.https_traffic_only_enabled == false
	msg := sprintf("azurerm_storage_account.%s: https_traffic_only_enabled must be true", [name])
}

deny[msg] {
	sa := input.resource.azurerm_storage_account[name]
	not sa.https_traffic_only_enabled
	msg := sprintf("azurerm_storage_account.%s: https_traffic_only_enabled must be set to true", [name])
}

deny[msg] {
	sa := input.resource.azurerm_storage_account[name]
	not sa.min_tls_version
	msg := sprintf("azurerm_storage_account.%s: min_tls_version must be set to 'TLS1_2'", [name])
}

deny[msg] {
	sa := input.resource.azurerm_storage_account[name]
	sa.min_tls_version != "TLS1_2"
	msg := sprintf(
		"azurerm_storage_account.%s: min_tls_version must be 'TLS1_2' (got '%s')",
		[name, sa.min_tls_version],
	)
}

deny[msg] {
	sa := input.resource.azurerm_storage_account[name]
	sa.allow_nested_items_to_be_public == true
	msg := sprintf("azurerm_storage_account.%s: allow_nested_items_to_be_public must be false", [name])
}

# blob_properties and delete_retention_policy are HCL blocks – parsed as objects
warn[msg] {
	blob := input.resource.azurerm_storage_account[name].blob_properties
	is_object(blob)
	drp := blob.delete_retention_policy
	is_object(drp)
	drp.days < 7
	msg := sprintf(
		"azurerm_storage_account.%s: blob_properties.delete_retention_policy.days must be >= 7 (got %d)",
		[name, drp.days],
	)
}

# ── Azure Kubernetes Service ──────────────────────────────────────────────────

deny[msg] {
	cluster := input.resource.azurerm_kubernetes_cluster[name]
	not cluster.role_based_access_control_enabled
	msg := sprintf("azurerm_kubernetes_cluster.%s: role_based_access_control_enabled must be true", [name])
}

deny[msg] {
	cluster := input.resource.azurerm_kubernetes_cluster[name]
	cluster.role_based_access_control_enabled == false
	msg := sprintf("azurerm_kubernetes_cluster.%s: role_based_access_control_enabled must be true", [name])
}

# network_profile is an HCL block – parsed as an object
warn[msg] {
	cluster := input.resource.azurerm_kubernetes_cluster[name]
	not cluster.network_profile
	msg := sprintf("azurerm_kubernetes_cluster.%s: a network_profile block with network_policy should be defined", [name])
}

warn[msg] {
	np := input.resource.azurerm_kubernetes_cluster[name].network_profile
	is_object(np)
	not np.network_policy
	msg := sprintf(
		"azurerm_kubernetes_cluster.%s: network_profile.network_policy should be set to 'azure' or 'calico'",
		[name],
	)
}

# azure_active_directory_role_based_access_control is an HCL block – parsed as an object
deny[msg] {
	aad := input.resource.azurerm_kubernetes_cluster[name].azure_active_directory_role_based_access_control
	is_object(aad)
	aad.managed == true
	not aad.azure_rbac_enabled
	msg := sprintf(
		"azurerm_kubernetes_cluster.%s: azure_active_directory_role_based_access_control.azure_rbac_enabled must be true when managed = true",
		[name],
	)
}

# ── Azure Key Vault ──────────────────────────────────────────────────────────

deny[msg] {
	kv := input.resource.azurerm_key_vault[name]
	not kv.purge_protection_enabled
	msg := sprintf("azurerm_key_vault.%s: purge_protection_enabled must be true", [name])
}

deny[msg] {
	kv := input.resource.azurerm_key_vault[name]
	kv.purge_protection_enabled == false
	msg := sprintf("azurerm_key_vault.%s: purge_protection_enabled must be true", [name])
}

deny[msg] {
	kv := input.resource.azurerm_key_vault[name]
	not kv.soft_delete_retention_days
	msg := sprintf("azurerm_key_vault.%s: soft_delete_retention_days must be set (minimum 7)", [name])
}

deny[msg] {
	kv := input.resource.azurerm_key_vault[name]
	kv.soft_delete_retention_days < 7
	msg := sprintf(
		"azurerm_key_vault.%s: soft_delete_retention_days must be >= 7 (got %d)",
		[name, kv.soft_delete_retention_days],
	)
}

# ── Azure Log Analytics Workspace ────────────────────────────────────────────

warn[msg] {
	law := input.resource.azurerm_log_analytics_workspace[name]
	law.retention_in_days < 30
	msg := sprintf(
		"azurerm_log_analytics_workspace.%s: retention_in_days should be >= 30 days (got %d)",
		[name, law.retention_in_days],
	)
}
