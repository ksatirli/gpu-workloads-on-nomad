# Virtual network for VM scale set and related workloads
# see https://registry.terraform.io/providers/hashicorp/azurerm/4.61.0/docs/resources/virtual_network
resource "azurerm_virtual_network" "main" {
  address_space       = var.azurerm_vnet_address_space
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-vnet"
  resource_group_name = azurerm_resource_group.main.name
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/4.61.0/docs/resources/subnet
resource "azurerm_subnet" "main" {
  address_prefixes = [
    var.azurerm_vmss_subnet_address_prefix
  ]

  name                 = "vmss"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
}
