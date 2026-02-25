# see https://registry.terraform.io/providers/hashicorp/azurerm/4.61.0/docs
provider "azurerm" {
  features {}

  subscription_id = var.azurerm_subscription_id
  use_cli         = true
}

# see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs
provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  ibmcloud_timeout = var.ibmcloud_timeout

  region     = var.ibmcloud_region
  visibility = var.ibmcloud_visibility
}

# see https://registry.terraform.io/providers/hashicorp/local/latest/docs
provider "local" {
  # The `local` provider has no configuration
}

# see https://registry.terraform.io/providers/hashicorp/random/latest/docs
provider "random" {
  # The `random` provider has no configuration
}

# see https://registry.terraform.io/providers/hashicorp/tls/latest/docs
provider "tls" {
  # The `tls` provider has no configuration
}