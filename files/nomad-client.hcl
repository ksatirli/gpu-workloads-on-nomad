datacenter = "dc1"

client {
  enabled = true
  # Configure Nomad server addresses - required for client to join cluster
  servers = ["127.0.0.1:4647"]
}

plugin "nomad-device-nvidia" {
  config {
    enabled = true
  }
}
