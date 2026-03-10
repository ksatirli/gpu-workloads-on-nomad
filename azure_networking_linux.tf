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
  tags                = var.tags
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb
resource "azurerm_lb" "main" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-lb"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = var.tags

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
  protocol        = "Http"
  request_path    = "/v1/agent/health"
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

resource "azurerm_lb_probe" "traefik" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "traefik-8080"
  port            = 8080
  protocol        = "Http"
  request_path    = "/ping"
}

resource "azurerm_lb_rule" "traefik" {
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  backend_port                   = 8080
  frontend_ip_configuration_name = "public"
  frontend_port                  = 8080
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "traefik-dashboard"
  probe_id                       = azurerm_lb_probe.traefik.id
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

resource "azurerm_lb_backend_address_pool" "windows" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  loadbalancer_id = azurerm_lb.main.id
  name            = "windows-backend"
}

resource "azurerm_network_interface_backend_address_pool_association" "windows" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  backend_address_pool_id = azurerm_lb_backend_address_pool.windows[0].id
  ip_configuration_name   = "internal"
  network_interface_id    = azurerm_network_interface.windows[0].id
}

# Minecraft Java Edition (TCP 25565) - runs on Linux VMSS
resource "azurerm_lb_probe" "minecraft_java" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "minecraft-java-25565"
  port            = 25565
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "minecraft_java" {
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  backend_port                   = 25565
  frontend_ip_configuration_name = "public"
  frontend_port                  = 25565
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "minecraft-java"
  probe_id                       = azurerm_lb_probe.minecraft_java.id
  protocol                       = "Tcp"
}

resource "azurerm_lb_rule" "minecraft_bedrock" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.windows[0].id]
  backend_port                   = 19132
  frontend_ip_configuration_name = "public"
  frontend_port                  = 19132
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "minecraft-bedrock"
  protocol                       = "Udp"
}

# Allow inbound traffic from configured source addresses
resource "azurerm_network_security_rule" "ingress_from_internet" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "AllowIngressFromInternet"
  network_security_group_name = azurerm_network_security_group.vmss.name
  priority                    = 120
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.main.name
  source_address_prefixes     = local.ingress_source_addresses
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = var.azurerm_ingress_ports
}

# Allow inbound UDP traffic (Minecraft Bedrock)
resource "azurerm_network_security_rule" "ingress_udp_from_internet" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "AllowUDPIngressFromInternet"
  network_security_group_name = azurerm_network_security_group.vmss.name
  priority                    = 125
  protocol                    = "Udp"
  resource_group_name         = azurerm_resource_group.main.name
  source_address_prefixes     = local.ingress_source_addresses
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["19132"]
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
  destination_port_ranges     = var.azurerm_ingress_ports
}
