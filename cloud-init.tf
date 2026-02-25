locals {
  # Advertise the load balancer address so the web UI and clients use the reachable public endpoint
  nomad_http_advertise = "${azurerm_public_ip.lb.ip_address}:4646"

  nomad_client_config_raw = templatefile("${path.module}/files/nomad-client.hcl.tpl", {
    subscription_id     = var.azurerm_subscription_id
    resource_group      = azurerm_resource_group.main.name
    vm_scale_set        = local.vm_scale_set_name
    http_advertise_addr = local.nomad_http_advertise
    acl_enabled         = var.nomad_acl_enabled
  })

  nomad_server_config_raw = templatefile("${path.module}/files/nomad-server.hcl.tpl", {
    subscription_id     = var.azurerm_subscription_id
    resource_group      = azurerm_resource_group.main.name
    vm_scale_set        = local.vm_scale_set_name
    bootstrap_expect    = var.nomad_server_count
    http_advertise_addr = local.nomad_http_advertise
    acl_enabled         = var.nomad_acl_enabled
  })

  cloud_init_linux_content = templatefile("${path.module}/files/cloud-init-linux-vmss.yaml.tpl", {
    nomad_client_config_b64 = base64encode(local.nomad_client_config_raw)
    nomad_server_config_b64 = base64encode(local.nomad_server_config_raw)
    nomad_server_count      = var.nomad_server_count
  })
}

# see https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file
resource "local_file" "cloud_init_linux" {
  content  = local.cloud_init_linux_content
  filename = "${path.module}/dist/cloud-init-linux.yml"
}

# see https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config
data "cloudinit_config" "linux_vmss" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = local.cloud_init_linux_content
  }
}
