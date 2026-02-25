# Linux VMSS networking - public load balancer and Nomad-related rules

# Nomad ports - allow traffic from other instances in the scale set (same subnet/VNet)
# see https://developer.hashicorp.com/nomad/docs/install/production/requirements
resource "azurerm_network_security_rule" "nomad_from_vnet" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "AllowNomadFromVNet"
  network_security_group_name = azurerm_network_security_group.vmss.name
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.main.name
  source_address_prefix       = var.azurerm_vnet_address_space[0]
  source_port_range           = "*"
  destination_address_prefix  = "*"

  destination_port_ranges = [
    "4646", # HTTP API
    "4647", # RPC
    "4648"  # Serf Gossip
  ]
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "lb" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-lb-pip"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb
resource "azurerm_lb" "main" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-lb"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool
resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "vmss-backend"
}

# Health probes for load balancer
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe
resource "azurerm_lb_probe" "http" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "http-80"
  port            = 80
  protocol        = "Tcp"
}

resource "azurerm_lb_probe" "https" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "https-443"
  port            = 443
  protocol        = "Tcp"
}

resource "azurerm_lb_probe" "nomad" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "nomad-4646"
  port            = 4646
  protocol        = "Tcp"
}

# Load balancing rules - HTTP, HTTPS, Nomad API
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule
resource "azurerm_lb_rule" "http" {
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  backend_port                   = 80
  frontend_ip_configuration_name = "public"
  frontend_port                  = 80
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "http"
  probe_id                       = azurerm_lb_probe.http.id
  protocol                       = "Tcp"
}

resource "azurerm_lb_rule" "https" {
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  backend_port                   = 443
  frontend_ip_configuration_name = "public"
  frontend_port                  = 443
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "https"
  probe_id                       = azurerm_lb_probe.https.id
  protocol                       = "Tcp"
}

resource "azurerm_lb_rule" "nomad_api" {
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  backend_port                   = 4646
  frontend_ip_configuration_name = "public"
  frontend_port                  = 4646
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "nomad-api"
  probe_id                       = azurerm_lb_probe.nomad.id
  protocol                       = "Tcp"
}

# Allow inbound HTTP, HTTPS, and Nomad API from Internet (remote access)
resource "azurerm_network_security_rule" "ingress_from_internet" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "AllowIngressFromInternet"
  network_security_group_name = azurerm_network_security_group.vmss.name
  priority                    = 120
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.main.name
  source_address_prefix       = "Internet"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["80", "443", "4646"]
}

# Allow Azure Load Balancer health probes (required for LB to mark backends healthy)
resource "azurerm_network_security_rule" "lb_health_probes" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "AllowAzureLoadBalancer"
  network_security_group_name = azurerm_network_security_group.vmss.name
  priority                    = 130
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.main.name
  source_address_prefix       = "AzureLoadBalancer"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["80", "443", "4646"]
}
