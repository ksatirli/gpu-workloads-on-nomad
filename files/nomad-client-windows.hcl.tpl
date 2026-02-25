datacenter = "dc1"
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
  enabled = true
}

# Join Nomad servers via internal load balancer (private IP)
server_join {
  retry_join = ["${nomad_server_address}:4648"]
  retry_max  = 0
}
