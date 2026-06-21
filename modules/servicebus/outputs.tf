output "servicebus_connection_string" {
  description = "Primary connection string for the Service Bus namespace"
  value       = azurerm_servicebus_namespace.sb.default_primary_connection_string
  sensitive   = true
}

output "servicebus_namespace_name" {
  description = "Name of the Service Bus namespace"
  value       = azurerm_servicebus_namespace.sb.name
}

output "dispatch_topic_name" {
  description = "Name of the dispatch.created topic"
  value       = azurerm_servicebus_topic.dispatch_created.name
}
