# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "boot_logs" {
  account_replication_type    = "LRS"
  account_tier               = "Standard"
  https_traffic_only_enabled = true
  location                   = azurerm_resource_group.main.location
  min_tls_version            = "TLS1_2"
  name                       = "${local.project_identifier_clean}bootlogs"
  resource_group_name        = azurerm_resource_group.main.name
  tags                       = var.tags
}
