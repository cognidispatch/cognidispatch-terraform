# Azure Service Bus Namespace
resource "azurerm_servicebus_namespace" "sb" {
  #checkov:skip=CKV_AZURE_201: Customer-managed key encryption requires Premium SKU
  #checkov:skip=CKV_AZURE_199: Double encryption requires Premium SKU
  #checkov:skip=CKV_AZURE_203: App uses SAS connection string from Key Vault; disabling local auth would break messaging
  #checkov:skip=CKV_AZURE_205: Minimum TLS version enforcement requires Premium SKU
  name                          = "sb-cognidispatch"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Standard"
  public_network_access_enabled = true # Enabled: allow connection over public IP

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Project     = "CogniDispatch"
    Environment = "Production"
  }
}

# Topic: dispatch.created
# Published by dispatch-service when a new dispatch is started
resource "azurerm_servicebus_topic" "dispatch_created" {
  name         = "dispatch-created"
  namespace_id = azurerm_servicebus_namespace.sb.id

  default_message_ttl        = "P14D" # 14 days TTL
  batched_operations_enabled = true
}

# Subscription: vendor-assignment
# Consumed by vendor-service to send email notifications to vendors
resource "azurerm_servicebus_subscription" "vendor_assignment" {
  name               = "vendor-assignment"
  topic_id           = azurerm_servicebus_topic.dispatch_created.id
  max_delivery_count = 5
  lock_duration      = "PT1M" # 1 minute lock

  dead_lettering_on_message_expiration = true
}
