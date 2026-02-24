output "private_key_openssh" {
  value     = tls_private_key.main.private_key_openssh
  sensitive = true
}

# SSH to VMSS instances via Azure Bastion
# Note: Get actual instance IDs with: az vmss list-instances -g nomad-gpu --name nomad-gpu-vmss -o table
output "ssh_via_bastion" {
  description = "SSH commands to connect to each VMSS instance via Bastion"
  value = [
    for i in range(var.azurerm_vmss_linux_instance_count) :
    "az network bastion ssh --name ${azurerm_bastion_host.main.name} --resource-group ${azurerm_resource_group.main.name} --target-resource-id /subscriptions/${var.azurerm_subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.Compute/virtualMachineScaleSets/${azurerm_linux_virtual_machine_scale_set.main.name}/virtualMachines/${i} --auth-type ssh-key --username ${var.azurerm_vmss_admin_username} --ssh-key ${abspath("${path.module}/dist/id_ed25519")}"
  ]
}

output "ssh_via_bastion_list_instances" {
  description = "Run this to get actual VMSS instance IDs (may differ from 0,1,2 after scale operations)"
  value       = "az vmss list-instances -g ${azurerm_resource_group.main.name} --name ${azurerm_linux_virtual_machine_scale_set.main.name} -o table"
}
