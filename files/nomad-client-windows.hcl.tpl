datacenter = "${datacenter}"
data_dir   = "C:\\Nomad\\data"

bind_addr = "0.0.0.0"
addresses {
  http = "0.0.0.0"
}

advertise {
  http = "${http_advertise_addr}"
}

http_api_response_headers {
  "Access-Control-Allow-Origin" = "*"
}

${acl_enabled ? "acl {\n  enabled = true\n}\n\n" : ""}client {
  enabled    = true
  node_class = "windows"

  drain_on_shutdown {
    deadline           = "5m"
    force              = true
    ignore_system_jobs = false
  }

  reserved {
    cpu    = 256
    memory = 512
    disk   = 1024
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}

# Join Nomad servers via internal load balancer (private IP)
server_join {
  retry_join = ["${nomad_server_address}:4648"]
  retry_max  = 0
}
