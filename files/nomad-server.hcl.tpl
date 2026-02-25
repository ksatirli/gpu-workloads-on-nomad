datacenter = "dc1"
data_dir   = "/opt/nomad/data"

# Bind HTTP API to all interfaces so it's reachable via load balancer (remote access)
# see https://developer.hashicorp.com/nomad/docs/configuration#addresses
bind_addr = "0.0.0.0"
addresses {
  http = "0.0.0.0"
}

# Advertise the load balancer address so the web UI uses the reachable public endpoint
# see https://developer.hashicorp.com/nomad/docs/deploy/clusters/reverse-proxy-ui
advertise {
  http = "${http_advertise_addr}"
}

# CORS headers for web UI (regions API and other browser requests)
http_api_response_headers {
  "Access-Control-Allow-Origin" = "*"
}

# ACLs - bootstrap manually when enabled: nomad acl bootstrap, then nomad acl policy apply anonymous files/nomad-anonymous.policy.hcl
${acl_enabled ? "acl {\n  enabled = true\n}\n\n" : ""}server {
  enabled          = true
  bootstrap_expect = ${bootstrap_expect}
}

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
