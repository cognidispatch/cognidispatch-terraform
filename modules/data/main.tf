data "azurerm_client_config" "current" {}

resource "azurerm_cosmosdb_account" "cosmos" {
  #checkov:skip=CKV_AZURE_100: Customer-managed key encryption for CosmosDB requires Key Vault key integration - not configured
  #checkov:skip=CKV_AZURE_132: Restricting management plane changes would prevent Terraform from managing CosmosDB
  name                 = "cosmos-cognidispatch-db"
  location             = "eastus2" # Match active location of CosmosDB
  resource_group_name  = var.resource_group_name
  offer_type           = "Standard"
  kind                 = "MongoDB"
  mongo_server_version = "4.2"

  automatic_failover_enabled = true

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = "eastus2"
    failover_priority = 0
  }

  geo_location {
    location          = "centralindia"
    failover_priority = 1
  }

  capabilities {
    name = "EnableMongo"
  }

  public_network_access_enabled = false
}

resource "azurerm_cosmosdb_mongo_database" "mongo_db" {
  name                = "cognidispatch"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

# Cosmos DB Private Endpoint
resource "azurerm_private_endpoint" "pe_cosmos" {
  name                = "pe-cosmosdb"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-cosmos"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }

  private_dns_zone_group {
    name                 = "cosmos-dns-zone-group"
    private_dns_zone_ids = [var.dns_zone_cosmos_id]
  }
}


data "http" "client_ip" {
  url = "https://api.ipify.org"
}

resource "azurerm_key_vault" "kv" {
  #checkov:skip=CKV_AZURE_110: Purge protection is intentionally disabled - enabling is irreversible and blocks terraform destroy for 90 days
  #checkov:skip=CKV_AZURE_42: Soft-delete is enabled (90 days retention); purge protection skipped for operational flexibility
  name                       = "cognidispatch-kv"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 90
  purge_protection_enabled   = false
  sku_name                   = "standard"

  public_network_access_enabled = true

  # Secure Network ACLs: restrict public access, allow private traffic
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = [chomp(data.http.client_ip.response_body)]
  }

  # Grant Terraform Service Principal access
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }

  lifecycle {
    ignore_changes = [
      access_policy,
      # network_acls is managed by the workflow (az keyvault network-rule add)
      # to handle the Plan runner IP ≠ Apply runner IP mismatch in GitHub Actions.
      # Terraform should not overwrite manually whitelisted IPs after initial creation.
      network_acls,
    ]
  }

  # On first-run: the KV doesn't exist at the start of the Apply job,
  # so the workflow's pre-apply whitelist step is skipped.
  # This provisioner adds the current caller's IP immediately after KV creation
  # so the subsequent secret writes in the same apply can succeed.
  provisioner "local-exec" {
    command = <<-EOT
      RUNNER_IP=$(curl -s https://api.ipify.org)
      echo "Adding runner IP $RUNNER_IP to KV firewall post-create..."
      az keyvault network-rule add \
        --name "${self.name}" \
        --resource-group "${self.resource_group_name}" \
        --ip-address "$RUNNER_IP" || true
      sleep 15
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Key Vault Private Endpoint
resource "azurerm_private_endpoint" "pe_kv" {
  name                = "pe-keyvault"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [var.dns_zone_kv_id]
  }
}
