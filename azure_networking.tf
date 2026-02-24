# Virtual network for VM scale set and related workloads
# see https://registry.terraform.io/providers/hashicorp/azurerm/4.61.0/docs/resources/virtual_network
resource "azurerm_virtual_network" "main" {
  address_space       = var.azurerm_vnet_address_space
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-vnet"
  resource_group_name = azurerm_resource_group.main.name
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "nat" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-nat-pip"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
}

# see https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/default-outbound-access
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway
resource "azurerm_nat_gateway" "main" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-nat"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
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
