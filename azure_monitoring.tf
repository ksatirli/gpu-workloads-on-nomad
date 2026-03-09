# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "main" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-logs"
  resource_group_name = azurerm_resource_group.main.name
  retention_in_days   = var.log_analytics_retention_days
  sku                 = "PerGB2018"
  tags                = var.tags
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_scale_set_extension
resource "azurerm_virtual_machine_scale_set_extension" "azure_monitor" {
  name                         = "AzureMonitorLinuxAgent"
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorLinuxAgent"
  type_handler_version         = "1.33"
  auto_upgrade_minor_version   = true
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.main.id
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
resource "azurerm_virtual_machine_extension" "azure_monitor_windows" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  name                       = "AzureMonitorWindowsAgent"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.22"
  auto_upgrade_minor_version = true
  virtual_machine_id         = azurerm_windows_virtual_machine.main[0].id
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule
resource "azurerm_monitor_data_collection_rule" "main" {
  location            = azurerm_resource_group.main.location
  name                = "${var.project_identifier}-dcr"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "logAnalytics"
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
    }
  }

  data_flow {
    destinations = ["logAnalytics"]
    streams      = ["Microsoft-Syslog", "Microsoft-Perf"]
  }

  data_sources {
    syslog {
      facility_names = ["daemon", "syslog"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "syslogDaemon"
      streams        = ["Microsoft-Syslog"]
    }

    performance_counter {
      counter_specifiers            = ["\\Processor(_Total)\\% Processor Time", "\\Memory\\Available Bytes", "\\LogicalDisk(_Total)\\% Free Space"]
      name                          = "perfCounters"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]
    }
  }
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule_association
resource "azurerm_monitor_data_collection_rule_association" "vmss" {
  name                    = "${var.project_identifier}-vmss-dcr"
  target_resource_id      = azurerm_linux_virtual_machine_scale_set.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.main.id
}

resource "azurerm_monitor_data_collection_rule_association" "windows" {
  count = var.azurerm_windows_instance_count > 0 ? 1 : 0

  name                    = "${var.project_identifier}-windows-dcr"
  target_resource_id      = azurerm_windows_virtual_machine.main[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.main.id
}
