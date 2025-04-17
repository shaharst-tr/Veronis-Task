################################################################
# Root-level outputs for the restaurant API project
################################################################

# Function App outputs
output "function_app_url" {
  description = "The default function app URL"
  value       = module.function_app.function_app_hostname
}

output "function_app_name" {
  description = "The name of the function app"
  value       = local.names.function_app
}

# Cosmos DB outputs
output "cosmos_db_endpoint" {
  description = "The endpoint of the Cosmos DB account"
  value       = module.cosmos_db.cosmos_db_endpoint
}

output "cosmos_db_name" {
  description = "The name of the Cosmos DB account"
  value       = module.cosmos_db.cosmos_db_name
}

# Key Vault outputs
output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = module.key_vault.key_vault_uri
}

# Storage outputs
output "storage_account_name" {
  description = "The name of the storage account"
  value       = module.function_app.storage_account_name
}

# Front Door outputs
output "api_endpoint" {
  description = "The secure API endpoint URL"
  value       = module.networking.frontdoor_endpoint
}

output "recommendation_api_url" {
  description = "The URL for restaurant recommendations"
  value       = "${module.networking.frontdoor_endpoint}/api/restaurant-recommend"
}

output "admin_api_url" {
  description = "The URL for admin operations"
  value       = "${module.networking.frontdoor_endpoint}/api/restaurants/admin"
}

output "health_check_url" {
  description = "The URL for health checks"
  value       = "${module.networking.frontdoor_endpoint}/api/health"
}