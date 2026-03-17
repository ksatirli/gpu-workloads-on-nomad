# Traefik reverse proxy - routes traffic to Nomad services
# see https://doc.traefik.io/traefik/providers/nomad/
variable "nomad_token" {
  type        = string
  description = "Nomad ACL token for service catalog discovery"
}

variable "image_version" {
  type        = string
  default     = "v3"
  description = "Container image version for traefik"
}

variable "datacenter" {
  default = "dc1"
}

job "traefik" {
  datacenters = [var.datacenter]
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
        image = "docker.io/library/traefik:${var.image_version}"
        ports = ["http", "api"]

        args = [
          "--api.dashboard=true",
          # NOTE: this is intentional for this demo, it is decidedly not a production-ready configuration
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
        data        = "NOMAD_TOKEN={{ with nomadVar \"nomad/jobs/traefik\" }}{{ .nomad_token }}{{ end }}"
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
