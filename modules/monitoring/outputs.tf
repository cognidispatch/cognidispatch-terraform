output "workspace_id" {
  description = "The ID of the Azure Monitor Workspace"
  value       = azurerm_monitor_workspace.workspace.id
}

output "grafana_endpoint" {
  description = "The secure public endpoint of Azure Managed Grafana"
  value       = azurerm_dashboard_grafana.grafana.endpoint
}
