# Virtual network for VM scale set and related workloads
# see https://registry.terraform.io/providers/hashicorp/azurerm/4.61.0/docs/resources/virtual_network
resource "azurerm_virtual_network" "main" {
  address_space       = var.azurerm_vnet_address_space
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "nat" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-nat-pip"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = var.tags
}

# see https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/default-outbound-access
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway
resource "azurerm_nat_gateway" "main" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-nat"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
  tags                = var.tags
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association
resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/4.61.0/docs/resources/subnet
resource "azurerm_subnet" "main" {
  address_prefixes = [
    var.azurerm_vmss_subnet_address_prefix
  ]

  default_outbound_access_enabled = false

  name                 = "vmss"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association
resource "azurerm_subnet_nat_gateway_association" "main" {
  nat_gateway_id = azurerm_nat_gateway.main.id
  subnet_id      = azurerm_subnet.main.id
}

# Network Security Group for VMSS - allows Nomad inter-instance communication
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group
resource "azurerm_network_security_group" "vmss" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-vmss-nsg"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Internal load balancer for Nomad server discovery (Windows client joins via private IP)
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb
resource "azurerm_lb" "internal" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-lb-internal"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.azurerm_vmss_subnet_address_prefix, 10)
    subnet_id                     = azurerm_subnet.main.id
  }
}

resource "azurerm_lb_backend_address_pool" "internal" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  loadbalancer_id = azurerm_lb.internal[0].id
  name            = "internal-backend"
}

resource "azurerm_lb_probe" "internal_nomad" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  loadbalancer_id = azurerm_lb.internal[0].id
  name            = "nomad-4648"
  port            = 4648
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "internal_nomad_rpc" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.internal[0].id]
  backend_port                   = 4647
  frontend_ip_configuration_name = "internal"
  frontend_port                  = 4647
  loadbalancer_id                = azurerm_lb.internal[0].id
  name                           = "nomad-rpc"
  probe_id                       = azurerm_lb_probe.internal_nomad[0].id
  protocol                       = "Tcp"
}

resource "azurerm_lb_rule" "internal_nomad_serf" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.internal[0].id]
  backend_port                   = 4648
  frontend_ip_configuration_name = "internal"
  frontend_port                  = 4648
  loadbalancer_id                = azurerm_lb.internal[0].id
  name                           = "nomad-serf"
  probe_id                       = azurerm_lb_probe.internal_nomad[0].id
  protocol                       = "Tcp"
}
