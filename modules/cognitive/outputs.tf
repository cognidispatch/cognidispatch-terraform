# Active OpenAI endpoint (eastus2 – gpt-4.1-mini, public access)
output "openai_endpoint" {
  description = "The active Azure OpenAI endpoint (eastus2, gpt-4.1-mini)"
  value       = azurerm_cognitive_account.openai_eastus2.endpoint
}

output "openai_deployment_name" {
  description = "The active Azure OpenAI deployment name"
  value       = azurerm_cognitive_deployment.gpt41mini.name
}

output "openai_eastus2_id" {
  description = "The resource ID of the active Azure OpenAI account (eastus2)"
  value       = azurerm_cognitive_account.openai_eastus2.id
}

output "openai_key" {
  description = "The primary access key of the active Azure OpenAI account (eastus2)"
  value       = azurerm_cognitive_account.openai_eastus2.primary_access_key
  sensitive   = true
}

# Legacy eastus resource – retained for private DNS zone continuity
output "openai_legacy_id" {
  description = "The resource ID of the legacy Azure OpenAI account (eastus, private)"
  value       = azurerm_cognitive_account.openai.id
}

output "speech_id" {
  description = "The resource ID of the Azure Speech account"
  value       = azurerm_cognitive_account.speech.id
}

output "speech_key" {
  description = "The primary access key of the Azure Speech account"
  value       = azurerm_cognitive_account.speech.primary_access_key
  sensitive   = true
}
