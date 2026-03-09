# Traefik reverse proxy - routes traffic to Nomad services
# see https://doc.traefik.io/traefik/providers/nomad/
job "traefik" {
  datacenters = ["dc1"]
  type        = "system"

  constraint {
    attribute = "${node.class}"
    value     = "linux"
  }

  group "traefik" {
    network {
      port "http" {
        static = 80
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name     = "traefik"
      port     = "http"
      provider = "nomad"

      check {
        type     = "http"
        path     = "/ping"
        port     = "api"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "traefik" {
      driver = "podman"

      config {
        image = "docker.io/library/traefik:v3"
        ports = ["http", "api"]

        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--ping=true",
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=http://${NOMAD_IP_http}:4646",
          "--providers.nomad.endpoint.token=${NOMAD_TOKEN}",
          "--providers.nomad.exposedByDefault=false",
        ]
      }

      # Scoped ACL token for reading Nomad service catalog
      template {
        data        = "NOMAD_TOKEN=641c80e6-2a17-6c1b-e1be-1a70d62ab425"
        destination = "secrets/nomad.env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
