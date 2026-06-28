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

# Key Vault Access Policy for Jumpbox VM (allows manual secret management)
resource "azurerm_key_vault_access_policy" "jumpbox_kv_policy" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.jumpbox_principal_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover"
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
  namespaces = ["cogni-dev", "cogni-dispatch"]

  fed_creds = {
    for pair in setproduct(local.namespaces, local.service_accounts) :
    "${pair[0]}-${pair[1]}" => {
      namespace       = pair[0]
      service_account = pair[1]
    }
  }
}

resource "azurerm_federated_identity_credential" "fed_cred" {
  for_each            = local.fed_creds
  name                = "fed-cred-${each.key}"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.pod_identity.id
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
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

# Role Assignment: Jumpbox VM identity needs "Azure Kubernetes Service Cluster User Role" to list cluster user credentials
resource "azurerm_role_assignment" "jumpbox_aks_user" {
  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.jumpbox_principal_id
}

# Role Assignment: Jumpbox VM identity needs "AcrPush" on ACR to build and push images
resource "azurerm_role_assignment" "jumpbox_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = var.jumpbox_principal_id
}

# Role Assignment: Jumpbox VM identity needs "Reader" on the Resource Group to view network settings (like public IPs)
resource "azurerm_role_assignment" "jumpbox_rg_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Reader"
  principal_id         = var.jumpbox_principal_id
}

# Role Assignment: Jumpbox VM identity needs "Network Contributor" on the Application Gateway to patch backend pools
resource "azurerm_role_assignment" "jumpbox_appgw_contributor" {
  scope                = var.app_gateway_id
  role_definition_name = "Network Contributor"
  principal_id         = var.jumpbox_principal_id
}

# Role Assignment: Jumpbox VM identity needs "Network Contributor" on the App Gateway subnet to allow backend pool join actions
resource "azurerm_role_assignment" "jumpbox_subnet_join" {
  scope                = var.app_gateway_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = var.jumpbox_principal_id
}

# ── GitHub Actions Service Principal Role Assignments for ACR ──
data "azuread_service_principal" "github_oidc" {
  display_name = "github-terraform-oidc"
}

data "azuread_service_principal" "terraform_sp" {
  display_name = "terraform-sp"
}

resource "azurerm_role_assignment" "github_oidc_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = data.azuread_service_principal.github_oidc.object_id
}

resource "azurerm_role_assignment" "terraform_sp_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = data.azuread_service_principal.terraform_sp.object_id
}

# ── GitHub Actions Service Principal Federated Credentials for Microservices ──
data "azuread_application" "github_oidc" {
  display_name = "github-terraform-oidc"
}

locals {
  github_org = "cognidispatch"
  microservice_repos = [
    "cognidispatch-admin-service",
    "cognidispatch-ai-service",
    "cognidispatch-auth-service",
    "cognidispatch-dispatch-service",
    "cognidispatch-frontend",
    "cognidispatch-payment-service",
    "cognidispatch-vendor-service",
  ]
  environments = ["dev", "production"]

  # Generate combination of repos and environments for OIDC trust
  github_fed_creds = merge(
    # Microservice credentials
    {
      for item in setproduct(local.microservice_repos, local.environments) :
      "${item[0]}-${item[1]}" => {
        repo        = item[0]
        subject     = "repo:${local.github_org}/${item[0]}:environment:${item[1]}"
        description = "GitHub OIDC for ${item[0]} in ${item[1]} environment"
      }
    },
    # Terraform repository credentials (preserve existing ones to avoid drift/recreation since they are matched by name)
    {
      "terraform-production-branch" = {
        repo        = "cognidispatch-terraform"
        subject     = "repo:${local.github_org}/cognidispatch-terraform:ref:refs/heads/production"
        description = "Trust for Terraform deployments from the production branch."
      },
      "terraform-production-env" = {
        repo        = "cognidispatch-terraform"
        subject     = "repo:${local.github_org}/cognidispatch-terraform:environment:production"
        description = "Trust for Terraform deployments in the production environment."
      },
      "terraform-main-trust" = {
        repo        = "cognidispatch-terraform"
        subject     = "repo:${local.github_org}/cognidispatch-terraform:ref:refs/heads/main"
        description = "Trust for Terraform deployments from the main branch."
      }
    }
  )
}

resource "azuread_application_federated_identity_credential" "github_repo_cred" {
  for_each       = local.github_fed_creds
  application_id = data.azuread_application.github_oidc.id
  display_name   = each.key
  description    = each.value.description
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value.subject
}



