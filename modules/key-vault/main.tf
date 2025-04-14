# modules/key-vault/main.tf - Key Vault resource definitions

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = var.soft_delete_retention_days
  purge_protection_enabled    = var.purge_protection_enabled
  sku_name                    = var.sku_name

  network_acls {
    default_action = var.network_acls_default_action
    bypass         = var.network_acls_bypass
    ip_rules       = var.allowed_ip_ranges
  }

  tags = var.tags
}

# Access policy for Terraform to manage secrets
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = "aa3d6aa5-e96a-4eb8-be74-cadb2e504e36"

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Purge"
  ]
}

# Create additional access policies for each object ID in the provided list
resource "azurerm_key_vault_access_policy" "additional" {
  for_each     = { for policy in var.access_policies : policy.object_id => policy }
  
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value.object_id
  
  secret_permissions = each.value.secret_permissions
  key_permissions    = each.value.key_permissions
  certificate_permissions = each.value.certificate_permissions
}