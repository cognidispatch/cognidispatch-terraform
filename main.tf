# Resource Group for CogniDispatch infrastructure.
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}

# Network Module: Hub & Spoke VNets, peerings, subnets, NSGs, and Private DNS Zones
module "network" {
  source              = "./modules/network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# AKS Module: Private AKS cluster
module "aks" {
  source              = "./modules/aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.network.snet_aks_id
  private_dns_zone_id = module.network.dns_aks_id
}

# Monitoring Module: Azure Managed Prometheus and Azure Managed Grafana
module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  aks_cluster_id      = module.aks.cluster_id
}

# Application Gateway Module: Load balancer and routing ingress
module "app_gateway" {
  source              = "./modules/app_gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.network.snet_appgw_id
}

# Data Module: Key Vault and Cosmos DB (MongoDB API) with Private Endpoints
module "data" {
  source              = "./modules/data"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.network.snet_pe_id
  dns_zone_cosmos_id  = module.network.dns_cosmos_id
  dns_zone_kv_id      = module.network.dns_kv_id
}

# Cognitive Module: Azure OpenAI and Speech Services with Private Endpoints
module "cognitive" {
  source              = "./modules/cognitive"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.network.snet_pe_id
  dns_zone_openai_id  = module.network.dns_openai_id
  dns_zone_speech_id  = module.network.dns_speech_id
}

# Registry Module: Azure Container Registry Premium SKU with Private Endpoint
module "registry" {
  source              = "./modules/registry"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.network.snet_pe_id
  dns_zone_acr_id     = module.network.dns_acr_id
}

# Bastion Module: Azure Bastion Host and Linux Jumpbox VM for secure shell administration
module "bastion" {
  source              = "./modules/bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  bastion_subnet_id   = module.network.snet_bastion_id
  mgmt_subnet_id      = module.network.snet_mgmt_id
  admin_username      = var.jumpbox_admin_username
  ssh_public_key      = var.jumpbox_ssh_public_key
  vm_size             = var.jumpbox_vm_size
}

# Security Module: Managed identities, Workload Identity federations, and role integrations
module "security" {
  source                     = "./modules/security"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  aks_cluster_id             = module.aks.cluster_id
  aks_oidc_issuer_url        = module.aks.oidc_issuer_url
  key_vault_id               = module.data.key_vault_id
  acr_id                     = module.registry.acr_id
  app_gateway_id             = module.app_gateway.app_gateway_id
  node_resource_group        = module.aks.node_resource_group
  kubelet_identity_object_id = module.aks.kubelet_identity_object_id
  jumpbox_principal_id       = module.bastion.jumpbox_principal_id
  app_gateway_subnet_id      = module.network.snet_appgw_id
}

# Dynamic application secrets written straight to Key Vault.
# depends_on = [module.data] ensures all secrets wait for the
# null_resource.kv_whitelist_runner_ip provisioner (inside module.data)
# to finish adding the runner IP + 15s sleep before writing secrets.
resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

resource "azurerm_key_vault_secret" "mongodb_uri" {
  name            = "MONGODB-URI"
  value           = replace(module.data.mongodb_uri, "/?", "/cognidispatch?")
  key_vault_id    = module.data.key_vault_id
  content_type    = "connection-string"
  expiration_date = "2027-12-31T23:59:59Z"
  depends_on      = [module.data]
}

resource "azurerm_key_vault_secret" "azure_openai_key" {
  name            = "AZURE-OPENAI-KEY"
  value           = module.cognitive.openai_key
  key_vault_id    = module.data.key_vault_id
  content_type    = "api-key"
  expiration_date = "2027-12-31T23:59:59Z"
  depends_on      = [module.data]
}

resource "azurerm_key_vault_secret" "azure_speech_key" {
  name            = "AZURE-SPEECH-KEY"
  value           = module.cognitive.speech_key
  key_vault_id    = module.data.key_vault_id
  content_type    = "api-key"
  expiration_date = "2027-12-31T23:59:59Z"
  depends_on      = [module.data]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name            = "JWT-SECRET"
  value           = random_password.jwt_secret.result
  key_vault_id    = module.data.key_vault_id
  content_type    = "text/plain"
  expiration_date = "2027-12-31T23:59:59Z"
  depends_on      = [module.data]
}

# ── Service Bus ────────────────────────────────────────────────────────────────
module "servicebus" {
  source              = "./modules/servicebus"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Store Service Bus connection string securely in Key Vault
resource "azurerm_key_vault_secret" "servicebus_connection" {
  name            = "SERVICEBUS-CONNECTION"
  value           = module.servicebus.servicebus_connection_string
  key_vault_id    = module.data.key_vault_id
  content_type    = "connection-string"
  expiration_date = "2027-12-31T23:59:59Z"
  depends_on      = [module.data]
}

# ── Email (SMTP via Gmail App Password or any SMTP provider) ───────────────────
# Store SMTP credentials in Key Vault — never hardcoded
# To set: az keyvault secret set --vault-name cognidispatch-kv --name SMTP-USER --value "you@gmail.com"
#         az keyvault secret set --vault-name cognidispatch-kv --name SMTP-PASS --value "your-app-password"
resource "azurerm_key_vault_secret" "smtp_user" {
  name            = "SMTP-USER"
  value           = var.smtp_user
  key_vault_id    = module.data.key_vault_id
  content_type    = "text/plain"
  expiration_date = "2027-12-31T23:59:59Z"
  depends_on      = [module.data]
}

resource "azurerm_key_vault_secret" "smtp_pass" {
  name            = "SMTP-PASS"
  value           = var.smtp_pass
  key_vault_id    = module.data.key_vault_id
  content_type    = "text/plain"
  expiration_date = "2027-12-31T23:59:59Z"
  depends_on      = [module.data]
}
