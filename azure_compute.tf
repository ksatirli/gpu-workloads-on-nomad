# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  admin_username      = var.azurerm_vmss_admin_username
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-vmss"
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.azurerm_vmss_sku
  instances           = var.azurerm_vmss_linux_instance_count

  admin_ssh_key {
    public_key = tls_private_key.main.public_key_openssh
    username   = var.azurerm_vmss_admin_username
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.main.id
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = var.azurerm_vmss_linux_source_image_reference.offer
    publisher = var.azurerm_vmss_linux_source_image_reference.publisher
    sku       = var.azurerm_vmss_linux_source_image_reference.sku
    version   = var.azurerm_vmss_linux_source_image_reference.version
  }
}
