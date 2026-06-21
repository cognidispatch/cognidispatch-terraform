# Azure Service Bus Namespace
resource "azurerm_servicebus_namespace" "sb" {
  name                = "sb-cognidispatch"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

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
