output "key_vault_id" {
  description = "Resource ID of the baseline Key Vault"
  value       = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  description = "Vault URI for the baseline Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}
