# see https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config
data "cloudinit_config" "linux_vmss" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/files/cloud-init-linux-vmss.yaml.tpl", {
      # Indent so content stays inside YAML literal block (avoids parser treating HCL as YAML keys)
      nomad_config = indent(6, templatefile("${path.module}/files/nomad-client.hcl.tpl", {
        subscription_id = var.azurerm_subscription_id
        resource_group  = azurerm_resource_group.main.name
        vm_scale_set    = local.vm_scale_set_name
      }))
    })
  }
}
