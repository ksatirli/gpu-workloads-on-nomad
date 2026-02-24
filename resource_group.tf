# TODO: enable when account supports multiple RGs
# # see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/resource_group
# resource "ibm_resource_group" "main" {
#   name = var.ibm_resource_group_name
# }

# # see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/resource_group
# data "ibm_resource_group" "default" {
#   name = "Default"
# }

# create a Resource Group for use with the HVN
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "main" {
  location = var.azurerm_location
  name     = var.project_identifier
}