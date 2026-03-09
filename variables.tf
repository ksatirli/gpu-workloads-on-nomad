variable "azurerm_location" {
  # see https://learn.microsoft.com/en-us/azure/reliability/regions-list
  default     = "westus" # West US, California
  description = "The Azure Region where the Resource Group should exist."
  type        = string
}

variable "azurerm_subscription_id" {
  type        = string
  description = "Azure Subscription ID."
}

variable "azurerm_vnet_address_space" {
  default = [
    "10.0.0.0/16"
  ]

  description = "The address space that is used the virtual network."
  type        = list(string)
}

variable "azurerm_vmss_subnet_address_prefix" {
  default     = "10.0.1.0/24" # /24 nets approx 250 usable IPs
  description = " The address prefixes to use for the subnet."
  type        = string
}

variable "azurerm_bastion_sku" {
  default     = "Basic"
  description = "SKU for Azure Bastion. Use Standard for native tunneling (SSH/RDP via az cli), Basic for portal-only access."
  type        = string

  validation {
    condition     = contains(["Basic", "Standard"], var.azurerm_bastion_sku)
    error_message = "azurerm_bastion_sku must be Basic or Standard."
  }
}

variable "azurerm_bastion_subnet_address_prefix" {
  default     = "10.0.0.0/26" # /26 minimum for AzureBastionSubnet
  description = "Address prefix for Azure Bastion subnet."
  type        = string
}

variable "azurerm_vmss_admin_username" {
  default     = "azureuser"
  description = "Admin username for the Linux VM scale set instances."
  type        = string
}

variable "azurerm_vmss_linux_instance_count" {
  default     = 3
  description = "Number of Linux VM instances in the scale set."
  type        = number
}

variable "azurerm_vmss_zones" {
  default     = ["1", "2", "3"]
  description = "Availability zones for the VMSS. Set to [] to disable zone distribution."
  type        = list(string)
}

variable "nomad_server_count" {
  default     = 3
  description = "Number of VMSS instances that run as Nomad servers (first N by instance ID). Use 3 or 5 for production quorum."
  type        = number

  validation {
    condition     = var.nomad_server_count >= 1 && var.nomad_server_count <= var.azurerm_vmss_linux_instance_count
    error_message = "nomad_server_count must be between 1 and azurerm_vmss_linux_instance_count."
  }
}

variable "nomad_datacenter" {
  default     = "dc1"
  description = "Nomad datacenter name used in all agent configs."
  type        = string
}

variable "nomad_acl_enabled" {
  default     = false
  description = "Toggle to enable Nomad ACLs."
  type        = bool
}

variable "nomad_version_windows" {
  default     = "1.11.2"
  description = "Nomad version to install on Windows clients."
  type        = string
}

variable "nomad_plugin_versions" {
  default = {
    device_nvidia = "1.1.0"
    driver_exec2  = "0.1.1"
    autoscaler    = "0.4.9"
  }
  description = "Versions of Nomad plugins installed on Linux VMSS instances."
  type = object({
    device_nvidia = string
    driver_exec2  = string
    autoscaler    = string
  })
}

variable "tags" {
  default = {
    project = "nomad-gpu-workloads"
    managed = "terraform"
  }
  description = "Tags applied to all Azure resources."
  type        = map(string)
}

variable "azurerm_vmss_windows_instance_count" {
  default     = 0
  description = "Number of Windows VM instances in the scale set."
  type        = number
}

variable "azurerm_windows_instance_count" {
  default     = 1
  description = "Number of standalone Windows VMs (Nomad clients). Set to 0 to disable."
  type        = number
}

variable "azurerm_windows_admin_username" {
  default     = "azureuser"
  description = "Admin username for the Windows VM."
  type        = string
}

variable "azurerm_windows_vm_size" {
  default     = "Standard_D2s_v3"
  description = "VM size for the Windows instance."
  type        = string
}

variable "azurerm_windows_source_image_reference" {
  default = {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  description = "Source image reference for the Windows VM."

  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "azurerm_vmss_sku" {
  # only N-Series VMs support GPU workloads
  default     = "Standard_B2s"
  description = "VM size for the scale set instances."
  type        = string
}

variable "azurerm_vmss_install_nvidia_gpu_extension" {
  default     = false
  description = "Install NVIDIA GPU driver extension on VMSS instances."
  type        = bool
}

variable "azurerm_vmss_linux_source_image_reference" {
  default = {
    offer     = "ubuntu-24_04-lts"
    publisher = "canonical"
    sku       = "server"
    version   = "latest"
  }

  description = "Source image reference for the Linux VM scale set."

  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "ibm_resource_group_name" {
  default     = "nomad-gpu-workloads"
  description = "The name of the resource group."
  type        = string
}

variable "ibmcloud_api_key" {
  # see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs#region-2
  default     = "us-south" # North America, Dallas
  description = "The IBM Cloud platform API key."
  type        = string
}

variable "ibmcloud_region" {
  # see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs#region-2
  default     = "us-south" # North America, Dallas
  description = "The IBM Cloud region."
  type        = string
}

variable "ibmcloud_timeout" {
  # see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs#ibmcloud_timeout-2
  default     = 60
  description = "The timeout, expressed in seconds, for interacting with IBM Cloud APIs."
  type        = number
}

variable "ibmcloud_visibility" {
  # see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs#visibility-2
  default     = "public"
  description = "The visibility to IBM Cloud endpoint."
  type        = string
}

variable "project_identifier" {
  default     = "nomad-gpu"
  description = "Project Identifier."
  type        = string

  validation {
    condition     = length(replace(var.project_identifier, "-", "")) <= 16
    error_message = "project_identifier (without hyphens) must be 16 characters or fewer for Azure storage account name limits."
  }
}

locals {
  project_identifier_clean = replace(var.project_identifier, "-", "")
}