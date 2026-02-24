# create a Resource Group for use with the HVN
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "main" {
  location = var.azurerm_location
  name     = var.project_identifier
}