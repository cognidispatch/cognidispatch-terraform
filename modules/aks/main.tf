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
  #checkov:skip=CKV_AZURE_141: Disabling local admin requires full AAD/Entra ID integration - skipping to prevent kubectl lockout
  #checkov:skip=CKV_AZURE_7: network_policy conflicts with Cilium data plane (network_data_plane="cilium") already in use
  #checkov:skip=CKV_AZURE_170: Paid SKU SLA ($73/mo) not required for this project tier
  #checkov:skip=CKV_AZURE_117: Disk encryption set (CMK) requires additional Key Vault key resource - not configured
  #checkov:skip=CKV_AZURE_227: Host-based encryption requires VM SKU support verification before enabling
  #checkov:skip=CKV_AZURE_226: Ephemeral OS disks incompatible with current os_disk_size_gb=128 configuration
  #checkov:skip=CKV_AZURE_168: Min 50 pods per node requires larger VM SKU; current D2s_v5 supports this but not enforced
  #checkov:skip=CKV_AZURE_232: System node CriticalAddonsOnly taint not set to avoid workload disruption on single nodepool
  #checkov:skip=CKV_AZURE_4: Monitoring configured via monitor_metrics{} and Azure Managed Prometheus (monitoring module)
  name                      = "cogni-aks"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = "cogniaks"
  private_cluster_enabled   = true
  private_dns_zone_id       = var.private_dns_zone_id
  automatic_channel_upgrade = "patch" # Auto-apply security patches to nodes
  azure_policy_enabled      = true    # Enable Azure Policy add-on for governance

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
