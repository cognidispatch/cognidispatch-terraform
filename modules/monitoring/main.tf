data "azurerm_client_config" "current" {}

# 1. Azure Monitor Workspace (stores Prometheus metrics)
resource "azurerm_monitor_workspace" "workspace" {
  name                = "mon-cognidispatch"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}

# 2. Azure Managed Grafana
resource "azurerm_dashboard_grafana" "grafana" {
  name                          = "grafana-cognidispatch"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  api_key_enabled               = true
  public_network_access_enabled = true
  grafana_major_version         = "12"

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.workspace.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}

# 3. Data Collection Endpoint (ingestion endpoint)
resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "MSProm-eastus-cogni-aks"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
}

# 4. Data Collection Rule (defines ingestion source & destination)
resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = "MSProm-eastus-cogni-aks"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.workspace.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }
}

# 5. Data Collection Rule Association (binds the DCR to AKS)
resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "MSProm-eastus-cogni-aks"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description             = "Association of data collection rule for Managed Prometheus"
}

# 6. Role Assignment: Allow Grafana to read from the Monitor Workspace
resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = azurerm_monitor_workspace.workspace.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# 7. Role Assignment: Grant Grafana Admin rights to the deploying user
resource "azurerm_role_assignment" "grafana_admin" {
  scope                = azurerm_dashboard_grafana.grafana.id
  role_definition_name = "Grafana Admin"
  principal_id         = var.grafana_admin_object_id
  principal_type       = "User"
}
