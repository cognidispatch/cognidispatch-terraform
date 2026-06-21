output "openai_endpoint" {
  description = "The endpoint of the Azure OpenAI account"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "openai_id" {
  description = "The resource ID of the Azure OpenAI account"
  value       = azurerm_cognitive_account.openai.id
}

output "openai_key" {
  description = "The primary access key of the Azure OpenAI account"
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
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
