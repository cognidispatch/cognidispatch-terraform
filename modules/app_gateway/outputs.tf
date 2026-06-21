output "public_ip_address" {
  description = "The public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "app_gateway_id" {
  description = "The resource ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.id
}

output "app_gateway_name" {
  description = "The name of the Application Gateway"
  value       = azurerm_application_gateway.appgw.name
}

output "waf_policy_id" {
  description = "The resource ID of the WAF policy attached to the Application Gateway"
  value       = azurerm_web_application_firewall_policy.waf_policy.id
}
