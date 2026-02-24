locals {
  nomad_config_raw = templatefile("${path.module}/files/nomad-client.hcl.tpl", {
    subscription_id = var.azurerm_subscription_id
    resource_group  = azurerm_resource_group.main.name
    vm_scale_set    = local.vm_scale_set_name
  })

  cloud_init_linux_content = templatefile("${path.module}/files/cloud-init-linux-vmss.yaml.tpl", {
    nomad_config_b64 = base64encode(local.nomad_config_raw)
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
