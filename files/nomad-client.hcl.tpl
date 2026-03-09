datacenter = "${datacenter}"
data_dir   = "/opt/nomad/data"

# Bind HTTP API to all interfaces so it's reachable via load balancer (remote access)
# see https://developer.hashicorp.com/nomad/docs/configuration#addresses
bind_addr = "0.0.0.0"
addresses {
  http = "0.0.0.0"
}

# Advertise the load balancer address so the web UI uses the reachable public endpoint
advertise {
  http = "${http_advertise_addr}"
}

# CORS headers for web UI
http_api_response_headers {
  "Access-Control-Allow-Origin" = "*"
}

# ACLs - must match server config
${acl_enabled ? "acl {\n  enabled = true\n}\n\n" : ""}client {
  enabled    = true
  node_class = "linux"

  drain_on_shutdown {
    deadline           = "5m"
    force              = true
    ignore_system_jobs = false
  }

  reserved {
    cpu    = 256
    memory = 256
    disk   = 1024
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}

# Auto-discover Nomad servers via Azure VMSS using Managed Service Identity
# see https://developer.hashicorp.com/nomad/docs/configuration/server_join#microsoft-azure
server_join {
  retry_join = [
    "provider=azure resource_group=${resource_group} vm_scale_set=${vm_scale_set} subscription_id=${subscription_id}"
  ]

  retry_max      = 0
  retry_interval = "15s"
}

# see https://developer.hashicorp.com/nomad/plugins/devices/nvidia
plugin "nomad-device-nvidia" {
  config {
    enabled = true
  }
}
