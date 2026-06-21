resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "waf-policy-cogni-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 2000
  }

  managed_rules {
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "image"
      selector_match_operator = "Equals"
    }

    exclusion {
      match_variable          = "RequestArgValues"
      selector                = "image"
      selector_match_operator = "Equals"
    }

    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  tags = {
    Environment = "Production"
    Project     = "CogniDispatch"
  }
}

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

  # WAF_v2 SKU - inline waf_configuration block is retired by Azure.
  # WAF policy is attached via firewall_policy_id instead.
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.waf_policy.id

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

  # Backend pool intentionally empty - populated by deploy.sh after
  # KGateway receives its dynamic ILB IP from Azure.
  backend_address_pool {
    name = "kgateway-backend-pool"
  }

  # Custom health probe - uses fixed host header since backend pool
  # is initially empty (populated by deploy.sh after KGateway ILB IP is assigned).
  probe {
    name                = "kgateway-health-probe"
    protocol            = "Http"
    path                = "/api/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

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

  # Ignore backend pool so deploy.sh can patch it with the KGateway ILB IP
  # without Terraform reverting it on subsequent applies.
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
