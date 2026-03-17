variable "image_version" {
  type        = string
  default     = "1.14.3"
  description = "Container image version for docling-serve"
}

# Docling - AI-powered document conversion API
# see https://github.com/docling-project/docling-serve
variable "datacenter" {
  default = "dc1"
}

job "docling" {
  datacenters = [var.datacenter]
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "linux"
  }

  group "api" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name     = "docling"
      port     = "http"
      provider = "nomad"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.docling.rule=PathPrefix(`/`)",
        "traefik.http.routers.docling.entrypoints=web",
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "15s"
        timeout  = "5s"
      }
    }

    scaling {
      min     = 1
      max     = 3
      enabled = true

      policy {
        evaluation_interval = "30s"
        cooldown            = "3m"

        check "cpu" {
          source = "nomad-apm"
          query  = "avg_cpu"

          strategy "target-value" {
            target = 70
          }
        }
      }
    }

    # The docling-serve image is large (~10 GB); allow time for the pull
    update {
      healthy_deadline  = "20m"
      progress_deadline = "25m"
    }

    restart {
      attempts = 3
      interval = "10m"
      delay    = "30s"
      mode     = "fail"
    }

    task "docling-serve" {
      driver = "podman"

      config {
        image              = "quay.io/docling-project/docling-serve:${var.image_version}"
        image_pull_timeout = "15m"
        ports              = ["http"]

        command = "docling-serve"
        args = [
          "run",
          "--host", "0.0.0.0",
          "--port", "${NOMAD_PORT_http}",
        ]
      }

      device "nvidia/gpu" {
        count = 1
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      env {
        DOCLING_SERVE_ENABLE_UI = "true"
      }
    }
  }
}
