# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "boot_logs" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.main.location
  name                     = "${local.project_identifier_clean}bootlogs"
  resource_group_name      = azurerm_resource_group.main.name
  tags                     = var.tags

  network_rules {
    default_action = "Allow"
  }
}
