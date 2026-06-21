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

  # WAF_v2 SKU enables Web Application Firewall with OWASP ruleset
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
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

  # Backend pool is intentionally left empty.
  # It is populated by deploy.sh after KGateway receives its ILB IP.
  backend_address_pool {
    name = "kgateway-backend-pool"
  }

  # Custom health probe on /api/health for more reliable backend detection
  probe {
    name                                      = "kgateway-health-probe"
    protocol                                  = "Http"
    path                                      = "/api/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                  = "kgateway-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "kgateway-health-probe"
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

  # Ignore backend pool changes so deploy.sh can patch it with the
  # dynamically-assigned KGateway ILB IP without Terraform reverting it.
  lifecycle {
    ignore_changes = [
      backend_address_pool,
    ]
  }

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}
