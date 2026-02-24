datacenter = "dc1"

client {
  enabled = true
}

# Auto-discover Nomad servers via Azure VMSS using Managed Service Identity
# see https://developer.hashicorp.com/nomad/docs/configuration/server_join#microsoft-azure
server_join {
  retry_join = [
    "provider=azure resource_group=${resource_group} vm_scale_set=${vm_scale_set} subscription_id=${subscription_id}"
  ]

  retry_max      = 0
  retry_interval = "30s"
}

# see https://developer.hashicorp.com/nomad/plugins/devices/nvidia
plugin "nomad-device-nvidia" {
  config {
    enabled = true
  }
}
