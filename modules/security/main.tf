# User-Assigned Managed Identity for Pod / Workload Identity
resource "azurerm_user_assigned_identity" "pod_identity" {
  name                = "cogni-pod-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Key Vault Access Policy for Pod Identity (allows fetching secrets)
resource "azurerm_key_vault_access_policy" "pod_kv_policy" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_user_assigned_identity.pod_identity.tenant_id
  object_id    = azurerm_user_assigned_identity.pod_identity.principal_id

  secret_permissions = [
    "Get", "List"
  ]
}

# OIDC Federated Identity Credentials for Microservices
locals {
  service_accounts = [
    "admin-service-sa",
    "ai-service-sa",
    "auth-service-sa",
    "dispatch-service-sa",
    "payment-service-sa",
    "vendor-service-sa",
    "frontend-sa"
  ]
}

resource "azurerm_federated_identity_credential" "fed_cred" {
  for_each            = toset(local.service_accounts)
  name                = "fed-cred-${each.key}"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.pod_identity.id
  subject             = "system:serviceaccount:cogni-dispatch:${each.key}"
}

# Role Assignment: Kubelet identity needs AcrPull on ACR
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "kubelet_acr" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_identity_object_id
}

# Role Assignment: Jumpbox VM identity needs "Azure Kubernetes Service Cluster Admin Role" on AKS Cluster
resource "azurerm_role_assignment" "jumpbox_aks_admin" {
  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = var.jumpbox_principal_id
}

# Role Assignment: Jumpbox VM identity needs "AcrPush" on ACR to build and push images
resource "azurerm_role_assignment" "jumpbox_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = var.jumpbox_principal_id
}

