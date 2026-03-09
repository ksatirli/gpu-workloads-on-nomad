# Standalone Windows VM as Nomad client
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine

resource "random_password" "windows_admin" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  length           = 20
  special          = true
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_network_interface" "windows" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-windows-nic"
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    primary                       = true
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.azurerm_vmss_subnet_address_prefix, 20)
  }
}

resource "azurerm_windows_virtual_machine" "main" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  admin_password       = random_password.windows_admin[0].result
  admin_username       = var.azurerm_windows_admin_username
  computer_name        = "nomad-win" # max 15 chars for Windows NetBIOS
  location             = azurerm_resource_group.main.location
  name                 = "${var.project_identifier}-windows"
  network_interface_ids = [azurerm_network_interface.windows[0].id]
  resource_group_name = azurerm_resource_group.main.name
  size                = var.azurerm_windows_vm_size

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  patch_mode = "AutomaticByPlatform" # required for hotpatch-enabled images (e.g. Windows Server 2025 Azure Edition)

  source_image_reference {
    offer     = var.azurerm_windows_source_image_reference.offer
    publisher = var.azurerm_windows_source_image_reference.publisher
    sku       = var.azurerm_windows_source_image_reference.sku
    version   = var.azurerm_windows_source_image_reference.version
  }
  tags = var.tags
}

# Associate Windows NIC with VMSS NSG so it can reach Nomad servers
resource "azurerm_network_interface_security_group_association" "windows" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  network_interface_id      = azurerm_network_interface.windows[0].id
  network_security_group_id = azurerm_network_security_group.vmss.id
}

# Custom Script Extension to install Nomad on Windows (only when Windows instance exists)
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
resource "azurerm_virtual_machine_extension" "nomad_install" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  name                 = "NomadInstall"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  virtual_machine_id   = azurerm_windows_virtual_machine.main[0].id

  # Only reference storage resources when count > 0 to avoid evaluation errors
  settings = var.azurerm_windows_instance_count > 0 ? jsonencode({
    fileUris         = ["${azurerm_storage_account.boot_logs.primary_blob_endpoint}${azurerm_storage_container.scripts[0].name}/${azurerm_storage_blob.nomad_install_script[0].name}?${data.azurerm_storage_account_sas.script[0].sas}"]
    commandToExecute = "powershell -ExecutionPolicy Bypass -File install-nomad-windows.ps1"
  }) : "{}"
}
