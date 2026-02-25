# Windows storage - Nomad install script for Custom Script Extension

# Container for Nomad install script (Windows)
resource "azurerm_storage_container" "scripts" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  name                 = "scripts"
  storage_account_id   = azurerm_storage_account.boot_logs.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "nomad_install_script" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  name                   = "install-nomad-windows.ps1"
  storage_account_name   = azurerm_storage_account.boot_logs.name
  storage_container_name = azurerm_storage_container.scripts[0].name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = local.nomad_install_script
}

# SAS token for Custom Script Extension to download the install script
data "azurerm_storage_account_sas" "script" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  connection_string = azurerm_storage_account.boot_logs.primary_connection_string
  https_only        = true
  signed_version    = "2017-07-29"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "24h")

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}
