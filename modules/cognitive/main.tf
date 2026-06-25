# Azure OpenAI Account
resource "azurerm_cognitive_account" "openai" {
  #checkov:skip=CKV_AZURE_236: App uses API key from Key Vault - disabling local auth would break AI service
  #checkov:skip=CKV2_AZURE_22: Customer-managed key encryption not required for this workload tier
  #checkov:skip=CKV_AZURE_247: Cognitive DLP is an enterprise Prisma Cloud feature, not applicable here
  name                          = "cogni-openai"
  location                      = "eastus" # Match active location of OpenAI
  resource_group_name           = var.resource_group_name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  public_network_access_enabled = false
  custom_subdomain_name         = "cogni-openai-93849"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}

# Azure OpenAI Account – eastus2 (active, public access, confirmed 200K TPM quota for gpt-4.1-mini)
# The legacy cogni-openai (eastus) is retained above for its private endpoint / DNS zone.
#
# TERRAFORM IMPORT – run these once before the first `terraform apply`:
#   terraform import 'module.cognitive.azurerm_cognitive_account.openai_eastus2' \
#     '/subscriptions/2cfa4708-9e24-48c2-b9c6-1e92f29781af/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/cogni-openai-eastus2'
resource "azurerm_cognitive_account" "openai_eastus2" {
  #checkov:skip=CKV_AZURE_236: App uses API key from Key Vault - disabling local auth would break AI service
  #checkov:skip=CKV2_AZURE_22: Customer-managed key encryption not required for this workload tier
  #checkov:skip=CKV_AZURE_247: Cognitive DLP is an enterprise Prisma Cloud feature, not applicable here
  name                          = "cogni-openai-eastus2"
  location                      = "eastus2"
  resource_group_name           = var.resource_group_name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  public_network_access_enabled = true # Public – AKS pods reach it via node egress IP

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}

# gpt-4.1-mini Deployment on cogni-openai-eastus2 (30K TPM GlobalStandard)
# TERRAFORM IMPORT – run once before first `terraform apply`:
#   terraform import 'module.cognitive.azurerm_cognitive_deployment.gpt41mini' \
#     '/subscriptions/2cfa4708-9e24-48c2-b9c6-1e92f29781af/resourceGroups/test-rg/providers/Microsoft.CognitiveServices/accounts/cogni-openai-eastus2/deployments/gpt-4.1-mini'
resource "azurerm_cognitive_deployment" "gpt41mini" {
  name                 = "gpt-4.1-mini"
  cognitive_account_id = azurerm_cognitive_account.openai_eastus2.id

  model {
    format  = "OpenAI"
    name    = "gpt-4.1-mini"
    version = "2025-04-14"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 30 # 30K TPM – eastus2 confirmed quota
  }
}

# OpenAI Private Endpoint
resource "azurerm_private_endpoint" "pe_openai" {
  name                = "pe-openai"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-openai"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "openai-dns-zone-group"
    private_dns_zone_ids = [var.dns_zone_openai_id]
  }
}


# Azure Speech Services Account
resource "azurerm_cognitive_account" "speech" {
  #checkov:skip=CKV_AZURE_236: App uses API key from Key Vault - disabling local auth would break speech service
  #checkov:skip=CKV2_AZURE_22: Customer-managed key encryption not required for this workload tier
  name                          = "cogni-speech"
  location                      = "eastus" # Match active location of Speech service
  resource_group_name           = var.resource_group_name
  kind                          = "SpeechServices"
  sku_name                      = "S0"
  public_network_access_enabled = false
  custom_subdomain_name         = "cogni-speech-93849"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}

# Speech Service Private Endpoint
resource "azurerm_private_endpoint" "pe_speech" {
  name                = "pe-speech"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-speech"
    private_connection_resource_id = azurerm_cognitive_account.speech.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "speech-dns-zone-group"
    private_dns_zone_ids = [var.dns_zone_speech_id]
  }
}
