# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  admin_username = var.azurerm_vmss_admin_username

  custom_data = base64encode(templatefile("${path.module}/files/cloud-init-linux.yaml.tpl", {
    nomad_config = indent(6, file("${path.module}/files/nomad-client.hcl"))
  }))

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
    name                      = "vmss-nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.vmss.id

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.main.id
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    offer     = var.azurerm_vmss_linux_source_image_reference.offer
    publisher = var.azurerm_vmss_linux_source_image_reference.publisher
    sku       = var.azurerm_vmss_linux_source_image_reference.sku
    version   = var.azurerm_vmss_linux_source_image_reference.version
  }
}

# NVIDIA GPU driver extension for N-series VMs
# see https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/hpccompute-gpu-linux
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_scale_set_extension
resource "azurerm_virtual_machine_scale_set_extension" "nvidia_gpu" {
  count = var.azurerm_vmss_install_nvidia_gpu_extension ? 1 : 0

  name                         = "NvidiaGpuDriverLinux"
  publisher                    = "Microsoft.HpcCompute"
  type                         = "NvidiaGpuDriverLinux"
  type_handler_version         = "1.6"
  auto_upgrade_minor_version   = true
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.main.id
}
