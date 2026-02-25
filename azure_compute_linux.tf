locals {
  vm_scale_set_name = "${var.project_identifier}-vmss"
}

# User-assigned identity for go-discover (principal_id known before VMSS creation)
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity
resource "azurerm_user_assigned_identity" "vmss" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-vmss-identity"
  resource_group_name = azurerm_resource_group.main.name
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  admin_username = var.azurerm_vmss_admin_username

  custom_data = data.cloudinit_config.linux_vmss.rendered

  location            = azurerm_resource_group.main.location
  name                = local.vm_scale_set_name
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
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.main.id
      load_balancer_backend_address_pool_ids = var.azurerm_windows_instance_count > 0 ? [azurerm_lb_backend_address_pool.main.id, azurerm_lb_backend_address_pool.internal[0].id] : [azurerm_lb_backend_address_pool.main.id]
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

  # Managed Service Identity for go-discover (user-assigned so principal_id exists at plan time)
  # see https://github.com/hashicorp/go-discover
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vmss.id]
  }
}

# RBAC: allow VMSS MSI to discover instances (required for go-discover provider=azure vm_scale_set)
# see https://developer.hashicorp.com/nomad/docs/configuration/server_join#microsoft-azure
resource "azurerm_role_assignment" "vmss_discovery" {
  principal_id         = azurerm_user_assigned_identity.vmss.principal_id
  role_definition_name = "Reader"
  scope                = azurerm_resource_group.main.id
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
