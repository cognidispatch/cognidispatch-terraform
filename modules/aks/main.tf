resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "cogni-aks-controlplane-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "aks_dns" {
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "azurerm_role_assignment" "aks_network" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = "cogni-aks"
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = "cogniaks"
  private_cluster_enabled = true
  private_dns_zone_id     = var.private_dns_zone_id

  depends_on = [
    azurerm_role_assignment.aks_dns,
    azurerm_role_assignment.aks_network
  ]

  default_node_pool {
    name                        = "agentpool"
    vm_size                     = "Standard_D2s_v5"
    vnet_subnet_id              = var.subnet_id
    os_disk_size_gb             = 128
    auto_scaling_enabled        = true
    min_count                   = 1
    max_count                   = 3
    temporary_name_for_rotation = "temppool"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    outbound_type       = "loadBalancer"
    network_data_plane  = "cilium"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  monitor_metrics {
  }

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}
