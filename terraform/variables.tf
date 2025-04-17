# variables.tf - Root module variables

variable "subscription_id" {
  description = "The Azure Subscription ID to deploy to"
  type        = string
}

variable "tenant_id" {
  description = "The Azure Tenant ID"
  type        = string
}

variable "project_name" {
  description = "Project name used as prefix for resources"
  type        = string
  default     = "restaurant-api"
}

variable "environment" {
  description = "Environment (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "West Europe"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_ip_ranges" {
  description = "List of IP addresses/ranges allowed to access resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Open by default - restrict this in production!
}

variable "cosmos_db_name" {
  description = "Name of the Cosmos DB database"
  type        = string
  default     = "restaurant-db"
}

variable "cosmos_container_name" {
  description = "Name of the Cosmos DB container"
  type        = string
  default     = "restaurants"
}

variable "key_vault_network_default_action" {
  description = "Default action for Key Vault network rules (Allow or Deny)"
  type        = string
  default     = "Deny"
}

variable "key_vault_network_bypass" {
  description = "Bypass settings for Key Vault network rules"
  type        = string
  default     = "AzureServices"
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}


variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "restaurant-api-rg"
}

variable "function_app_name" {
  description = "Name of the Azure Function App"
  type        = string
  default     = "restaurant-api-func-y"
}
