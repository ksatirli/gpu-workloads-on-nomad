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
  description = "The address prefixes to use for the subnet."
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
  default     = []
  description = "Availability zones for the VMSS (e.g. [\"1\", \"2\", \"3\"]). Requires a zone-capable region. Set to [] to disable."
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

variable "azurerm_sas_token_expiry" {
  default     = "24h"
  description = "Duration for storage account SAS token validity (e.g. 24h, 48h, 168h)."
  type        = string
}

variable "log_analytics_retention_days" {
  default     = 30
  description = "Number of days to retain logs in Log Analytics workspace."
  type        = number
}

variable "azurerm_ingress_source_addresses" {
  default     = null
  description = "Source IP addresses (CIDR) allowed to reach ingress ports. Defaults to the current public IP of the Terraform runner if not set."
  type        = list(string)
}

variable "azurerm_ingress_ports" {
  default     = ["80", "4646", "8080", "25565"]
  description = "TCP destination ports opened in the VMSS NSG for external ingress. UDP ports (e.g. 19132 for Minecraft Bedrock) are handled by dedicated rules."
  type        = list(string)
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

variable "nomad_iis_version" {
  default     = "0.19.0"
  description = "Version of the nomad-iis task driver plugin for Windows clients."
  type        = string
}

variable "java_jre" {
  default = {
    version  = "21.0.10+7"
    sha256   = "a6ac6789e51a2c245f41430c42e72b39ec706a449812fc5e4cbfc55ceed1e5ae"
    filename = "OpenJDK21U-jre_x64_windows_hotspot_21.0.10_7.zip"
  }
  description = "Adoptium Temurin JRE version, SHA256 checksum, and archive filename for Windows x64."
  type = object({
    version  = string
    sha256   = string
    filename = string
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
  description = "Install NVIDIA GPU driver extension on the main (non-GPU) VMSS instances."
  type        = bool
}

variable "azurerm_vmss_gpu_enabled" {
  default     = true
  description = "Whether to create a dedicated GPU VMSS alongside the main VMSS."
  type        = bool
}

variable "azurerm_vmss_gpu_sku" {
  default     = "Standard_NC4as_T4_v3"
  description = "VM size for the GPU scale set instances (must be N-series for GPU support)."
  type        = string
}

variable "azurerm_vmss_gpu_instance_count" {
  default     = 1
  description = "Number of GPU VM instances in the GPU scale set."
  type        = number
}

variable "azurerm_vmss_nvidia_gpu_extension_version" {
  default     = "1.6"
  description = "Version of the NVIDIA GPU driver extension for VMSS."
  type        = string
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

variable "project_identifier" {
  default     = "nomad-gpu"
  description = "Project Identifier."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_identifier))
    error_message = "project_identifier must contain only lowercase letters, digits, and hyphens."
  }

  validation {
    condition     = length(replace(var.project_identifier, "-", "")) <= 16
    error_message = "project_identifier (without hyphens) must be 16 characters or fewer for Azure storage account name limits."
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  project_identifier_clean = lower(replace(var.project_identifier, "-", ""))

  # Use provided source addresses, or fall back to the Terraform runner's public IP
  ingress_source_addresses = coalesce(var.azurerm_ingress_source_addresses, ["${trimspace(data.http.my_ip.response_body)}/32"])
}