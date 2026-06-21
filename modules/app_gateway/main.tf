resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-cogni-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "cogni-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name         = "kgateway-backend-pool"
    ip_addresses = ["10.224.0.100"]
  }

  backend_http_settings {
    name                  = "kgateway-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "kgateway-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "kgateway-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "kgateway-listener"
    backend_address_pool_name  = "kgateway-backend-pool"
    backend_http_settings_name = "kgateway-http-settings"
    priority                   = 100
  }


  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}
