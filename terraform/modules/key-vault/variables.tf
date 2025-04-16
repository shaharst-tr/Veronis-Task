# modules/key-vault/variables.tf - Variable definitions for the Key Vault module

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region to deploy the Key Vault"
  type        = string
}

variable "sku_name" {
  description = "SKU name for the Key Vault (standard or premium)"
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain deleted vaults"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Whether to enable purge protection"
  type        = bool
  default     = false
}

variable "network_acls_default_action" {
  description = "Default action for network ACLs (Allow or Deny)"
  type        = string
  default     = "Deny"
}

variable "network_acls_bypass" {
  description = "Services that can bypass network ACLs (AzureServices, None)"
  type        = string
  default     = "AzureServices"
}

variable "allowed_ip_ranges" {
  description = "List of IP addresses/ranges allowed to access Key Vault"
  type        = list(string)
  default     = []
}

variable "access_policies" {
  description = "List of access policies for the Key Vault"
  type = list(object({
    object_id               = string
    secret_permissions      = list(string)
    key_permissions         = list(string)
    certificate_permissions = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the Key Vault"
  type        = map(string)
  default     = {}
}