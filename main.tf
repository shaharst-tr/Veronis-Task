# main.tf - Provider configuration and main resources

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" 
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

locals {
  # Naming convention
  name_prefix = "${var.project_name}"
  
  # Resource-specific names
  names = {
    resource_group  = "${local.name_prefix}-rg"
    key_vault       = "${local.name_prefix}-kv"
    cosmos_account  = "${local.name_prefix}-cosmos"
    function_app    = "${local.name_prefix}-func"
    storage_account = lower(replace("${var.project_name}${var.environment}sa", "-", ""))
    app_insights    = "${local.name_prefix}-insights"
    app_plan        = "${local.name_prefix}-plan"
    logs_workspace  = "${local.name_prefix}-logs"
    user_identity   = "${local.name_prefix}-identity"
  }
  
  # Database configuration
  cosmos_config = {
    database_name   = var.cosmos_db_name
    container_name  = var.cosmos_container_name
    partition_key   = "/style"
  }
  
  # Common tags that apply to all resources
  common_tags = merge(var.tags, {
    environment = var.environment
    project     = var.project_name
    terraform   = "true"
  })
  
  # Function app settings
  function_app_settings = {
    COSMOS_DATABASE   = local.cosmos_config.database_name
    COSMOS_CONTAINER  = local.cosmos_config.container_name
    COSMOS_ENDPOINT   = "@Microsoft.KeyVault(SecretUri=${module.key_vault.key_vault_uri}secrets/cosmos-endpoint/)"
    COSMOS_KEY        = "@Microsoft.KeyVault(SecretUri=${module.key_vault.key_vault_uri}secrets/cosmos-key/)"
  }
}

# Create resource group
resource "azurerm_resource_group" "rg" {
  name     = local.names.resource_group
  location = var.location
  tags     = local.common_tags
}

# Create user-assigned managed identity
resource "azurerm_user_assigned_identity" "api_identity" {
  name                = local.names.user_identity
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.common_tags
}

# Call the Key Vault module
module "key_vault" {
  source = "./modules/key-vault"

  key_vault_name      = local.names.key_vault
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  
  # Network settings
  network_acls_default_action = var.key_vault_network_default_action
  network_acls_bypass         = var.key_vault_network_bypass
  allowed_ip_ranges           = var.allowed_ip_ranges
  
  tags = local.common_tags
}

# Call the Cosmos DB module
module "cosmos_db" {
  source = "./modules/cosmos-db"
  
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  cosmos_account_name = local.names.cosmos_account
  database_name       = local.cosmos_config.database_name
  container_name      = local.cosmos_config.container_name
  partition_key_path  = local.cosmos_config.partition_key
  
  # Store secrets in Key Vault
  key_vault_id        = module.key_vault.key_vault_id
  
  tags = local.common_tags
  
  depends_on = [
    module.key_vault
  ]
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  name         = "cosmos-endpoint"
  value        = module.cosmos_db.cosmos_db_endpoint
  key_vault_id = module.key_vault.key_vault_id
  
  depends_on = [
    module.key_vault,
    module.cosmos_db
  ]
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "cosmos-key"
  value        = module.cosmos_db.cosmos_db_primary_key
  key_vault_id = module.key_vault.key_vault_id
  
  depends_on = [
    module.key_vault,
    module.cosmos_db
  ]
}

# module "function_app" {
#   source = "./modules/function-app"
  
#   resource_group_name   = azurerm_resource_group.rg.name
#   location              = var.location
#   function_app_name     = "${var.project_name}-${var.environment}-func"
#   storage_account_name  = lower(replace("${var.project_name}${var.environment}sa", "-", ""))
#   app_service_plan_name = "${var.project_name}-${var.environment}-plan"
  
#   tags = local.common_tags
# }

# # Add Function App's identity to Key Vault access policies (if needed)
# resource "azurerm_key_vault_access_policy" "function_access_policy" {
#   key_vault_id = module.key_vault.key_vault_id
#   tenant_id    = var.tenant_id
#   object_id    = module.function_app.function_app_principal_id
  
#   secret_permissions = [
#     "Get",
#     "List"
#   ]
  
#   depends_on = [
#     module.key_vault,
#     module.function_app
#   ]
# }

# Call the Function App module (with user-assigned identity)
module "function_app" {
  source = "./modules/function-app"
  
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  function_app_name     = local.names.function_app
  storage_account_name  = local.names.storage_account
  app_insights_name     = local.names.app_insights
  app_service_plan_name = local.names.app_plan
  
  # User-assigned identity configuration
  identity_type         = "UserAssigned"
  identity_ids          = [azurerm_user_assigned_identity.api_identity.id]
  
  # App settings - reference secrets from Key Vault
  additional_app_settings = local.function_app_settings
  
  tags = local.common_tags
  
  depends_on = [
    module.key_vault,
    module.cosmos_db,
    azurerm_user_assigned_identity.api_identity
  ]
}

# Add Function App's identity to Key Vault access policies
resource "azurerm_key_vault_access_policy" "function_access_policy" {
  key_vault_id = module.key_vault.key_vault_id
  tenant_id    = var.tenant_id
  object_id    = azurerm_user_assigned_identity.api_identity.principal_id
  
  secret_permissions = [
    "Get",
    "List"
  ]
  
  depends_on = [
    module.key_vault,
    azurerm_user_assigned_identity.api_identity
  ]
}

# Add role assignment for Cosmos DB data access
resource "azurerm_cosmosdb_sql_role_assignment" "function_cosmos_data_contributor" {
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = module.cosmos_db.cosmos_db_name
  role_definition_id  = "${module.cosmos_db.cosmos_db_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" # Built-in Data Contributor role
  principal_id        = azurerm_user_assigned_identity.api_identity.principal_id
  scope               = module.cosmos_db.cosmos_db_id
  
  depends_on = [
    module.cosmos_db,
    azurerm_user_assigned_identity.api_identity
  ]
}

# Log Analytics workspace for Function App logs only
resource "azurerm_log_analytics_workspace" "logs" {
  name                = local.names.logs_workspace
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_retention_days
  
  tags = local.common_tags
}

# Diagnostic settings just for Function App (not for Key Vault)
resource "azurerm_monitor_diagnostic_setting" "function_logs" {
  name                       = "function-diagnostic-logs"
  target_resource_id         = module.function_app.function_app_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
  
  log {
    category = "FunctionAppLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
    }
  }
  
  metric {
    category = "AllMetrics"
    enabled  = true
    
    retention_policy {
      enabled = true
    }
  }
}