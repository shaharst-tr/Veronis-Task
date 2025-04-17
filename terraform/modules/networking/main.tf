################################################################
# Networking Module for Restaurant API
# Configures Azure Front Door with the function app backend
################################################################

# Front Door profile (Premium tier for enhanced security features)
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "fd-${replace(var.resource_group_name, "-rg", "")}"
  resource_group_name = var.resource_group_name
  sku_name            = "Premium_AzureFrontDoor"

  tags = var.tags
}

# Front Door endpoint
resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "endpoint-${replace(var.resource_group_name, "-rg", "")}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  tags = var.tags
}

# Front Door origin group for the restaurant API
resource "azurerm_cdn_frontdoor_origin_group" "restaurant_api" {
  name                     = "restaurant-api-origin"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  
  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    interval_in_seconds = 120
    path                = "/api/health"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

# Front Door origin (function app backend)
resource "azurerm_cdn_frontdoor_origin" "function_app" {
  name                          = "function-app-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.restaurant_api.id
  
  enabled                       = true
  host_name                     = var.function_app_hostname
  http_port                     = 80
  https_port                    = 443
  origin_host_header            = var.function_app_hostname
  priority                      = 1
  weight                        = 1000
  certificate_name_check_enabled = true
}

# Web Application Firewall Policy
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                = "wafpolicy-${replace(var.resource_group_name, "-rg", "")}"
  resource_group_name = var.resource_group_name
  sku_name            = azurerm_cdn_frontdoor_profile.main.sku_name
  enabled             = true
  mode                = var.waf_mode

  # Default rules to protect against common web vulnerabilities
  managed_rule {
    type    = "DefaultRuleSet"
    version = "2.0"
    action  = "Block"
  }

  # Bot protection rules
  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  # Custom rules for additional security
  custom_rule {
    name                           = "BlockUnwantedUserAgents"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 100
    type                           = "MatchRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RequestHeader"
      match_values       = ["curl", "postman", "wget"]
      operator           = "Contains"
      selector           = "User-Agent"
      negation_condition = false
      transforms         = ["Lowercase"]
    }
  }

  tags = var.tags
}

# Front Door security policy
resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id
      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

# Front Door route for public restaurant recommendations API
resource "azurerm_cdn_frontdoor_route" "recommendations" {
  name                          = "recommendations-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.restaurant_api.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.function_app.id]
  
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/api/restaurant-recommend*"]
  forwarding_protocol           = "HttpsOnly"
  link_to_default_domain        = true
  
  # Cache configuration optimized for the restaurant API
  cache {
    query_string_caching_behavior = "IncludeSpecifiedQueryStrings"
    query_strings                 = ["style", "vegetarian", "deliveries", "priceRange", "openNow"]
    compression_enabled           = true
    content_types_to_compress     = ["application/json"]
  }
}

# Front Door route for admin operations (no caching)
resource "azurerm_cdn_frontdoor_route" "admin" {
  name                          = "admin-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.restaurant_api.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.function_app.id]
  
  supported_protocols           = ["Https"]
  patterns_to_match             = ["/api/restaurants/admin*"]
  forwarding_protocol           = "HttpsOnly"
  link_to_default_domain        = true
  
  # No caching for admin operations
}

# Front Door route for health check
resource "azurerm_cdn_frontdoor_route" "health" {
  name                          = "health-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.restaurant_api.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.function_app.id]
  
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/api/health"]
  forwarding_protocol           = "HttpsOnly"
  link_to_default_domain        = true
}

# Virtual network for function app
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${replace(var.resource_group_name, "-rg", "")}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Subnet for function app integration
resource "azurerm_subnet" "function_integration" {
  name                 = "snet-function-integration"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.function_subnet_prefix
  
  delegation {
    name = "function-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.AzureCosmosDB"]
}

# Network Security Group for the function app subnet
resource "azurerm_network_security_group" "function" {
  name                = "nsg-function"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Allow only Azure Front Door traffic
resource "azurerm_network_security_rule" "allow_frontdoor" {
  name                        = "AllowAzureFrontDoor"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.function.name
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "function" {
  subnet_id                 = azurerm_subnet.function_integration.id
  network_security_group_id = azurerm_network_security_group.function.id
}

# Add IP restriction to function app to only allow Front Door
resource "azurerm_app_service_virtual_network_swift_connection" "function_vnet_integration" {
  app_service_id = var.function_app_id
  subnet_id      = azurerm_subnet.function_integration.id
}

# Diagnostic settings for Front Door
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  name                       = "fd-diag-logs"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontdoorAccessLog"
  }

  enabled_log {
    category = "FrontdoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# CDN rule set for optimizing restaurant API
resource "azurerm_cdn_frontdoor_rule_set" "api_optimization" {
  name                     = "apioptimization"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

# Rule to set cache control headers for recommendation API
resource "azurerm_cdn_frontdoor_rule" "cache_control" {
  name                      = "SetCacheControlHeaders"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.api_optimization.id
  order                     = 1

  conditions {
    url_path_condition {
      operator     = "BeginsWith"
      match_values = ["/api/restaurant-recommend"]
    }
  }

  actions {
    response_header_action {
      header_action = "Append"
      header_name   = "Cache-Control"
      value         = "max-age=60"
    }
  }
}