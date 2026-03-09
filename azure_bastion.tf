resource "azurerm_subnet" "bastion" {
  address_prefixes     = [var.azurerm_bastion_subnet_address_prefix]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
}

resource "azurerm_public_ip" "bastion" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-bastion-pip"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-bastion"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = var.tags
  tunneling_enabled   = true

  ip_configuration {
    name                 = "configuration"
    public_ip_address_id = azurerm_public_ip.bastion.id
    subnet_id            = azurerm_subnet.bastion.id
  }
}

# Allow Bastion to reach VMSS instances on SSH (Bastion initiates outbound to targets)
resource "azurerm_network_security_rule" "ssh_from_bastion" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "AllowSSHFromBastion"
  network_security_group_name = azurerm_network_security_group.vmss.name
  priority                    = 110
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.main.name
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
}

# Allow Bastion to reach Windows VM on RDP
resource "azurerm_network_security_rule" "rdp_from_bastion" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "AllowRDPFromBastion"
  network_security_group_name = azurerm_network_security_group.vmss.name
  priority                    = 111
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.main.name
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
}
