output "private_key_openssh" {
  value     = tls_private_key.main.private_key_openssh
  sensitive = true
}

# SSH to VMSS instances via Azure Bastion
# VMSS instance IDs may not be sequential (e.g. 0,3,4 after scale operations).
# Use the list command below to get actual IDs, then substitute into the template.
output "ssh_via_bastion_template" {
  description = "SSH command template — replace <INSTANCE_ID> with actual ID from ssh_via_bastion_list_instances"
  value       = "az network bastion ssh --name ${azurerm_bastion_host.main.name} --resource-group ${azurerm_resource_group.main.name} --target-resource-id /subscriptions/${var.azurerm_subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.Compute/virtualMachineScaleSets/${azurerm_linux_virtual_machine_scale_set.main.name}/virtualMachines/<INSTANCE_ID> --auth-type ssh-key --username ${var.azurerm_vmss_admin_username} --ssh-key ${abspath("${path.module}/dist/id_ed25519")}"
}

output "ssh_via_bastion_list_instances" {
  description = "List actual VMSS instance IDs for use with ssh_via_bastion_template"
  value       = "az vmss list-instances -g ${azurerm_resource_group.main.name} --name ${azurerm_linux_virtual_machine_scale_set.main.name} -o table"
}

# Load balancer public IP for Traefik ingress and Nomad API remote access
output "load_balancer_public_ip" {
  description = "Public IP of the load balancer for HTTP (80) and Nomad API (4646)"
  value       = azurerm_public_ip.lb.ip_address
}

output "windows_admin_password" {
  description = "Admin password for Windows VM instances"
  value       = var.azurerm_windows_instance_count > 0 ? random_password.windows_admin[0].result : null
  sensitive   = true
}

output "internal_load_balancer_ip" {
  description = "Private IP of the internal load balancer used for Nomad server discovery"
  value       = var.azurerm_windows_instance_count > 0 ? azurerm_lb.internal[0].frontend_ip_configuration[0].private_ip_address : null
}

output "load_balancer_endpoints" {
  description = "Remote access URLs for Traefik and Nomad API"
  value = {
    http      = "http://${azurerm_public_ip.lb.ip_address}"
    nomad_api = "http://${azurerm_public_ip.lb.ip_address}:4646"
  }
}
