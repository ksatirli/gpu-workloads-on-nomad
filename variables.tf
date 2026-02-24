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
}

