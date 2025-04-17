################################################################
# Networking Module Outputs
################################################################

output "frontdoor_endpoint" {
  description = "The Front Door endpoint URL"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
}

output "frontdoor_id" {
  description = "The Front Door profile ID"
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "frontdoor_hostname" {
  description = "The Front Door endpoint hostname"
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "function_subnet_id" {
  description = "The ID of the subnet used for function app integration"
  value       = azurerm_subnet.function_integration.id
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "waf_policy_id" {
  description = "The ID of the Web Application Firewall policy"
  value       = azurerm_cdn_frontdoor_firewall_policy.main.id
}