# outputs.tf - Root module outputs

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the resource group"
}

output "key_vault_name" {
  value       = module.key_vault.key_vault_name
  description = "The name of the Key Vault"
}

output "key_vault_uri" {
  value       = module.key_vault.key_vault_uri
  description = "The URI of the Key Vault"
}