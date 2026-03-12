variable "image_version" {
  type        = string
  default     = "0.17.7"
  description = "Container image version for ollama"
}

# Ollama - local LLM inference server
# see https://github.com/ollama/ollama
job "ollama" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "linux"
  }

  group "ollama" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name     = "ollama"
      port     = "http"
      provider = "nomad"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.ollama.rule=PathPrefix(`/ollama`)",
        "traefik.http.routers.ollama.entrypoints=web",
        "traefik.http.middlewares.ollama-strip.stripprefix.prefixes=/ollama",
        "traefik.http.routers.ollama.middlewares=ollama-strip",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "15s"
        timeout  = "5s"
      }
    }

    update {
      healthy_deadline  = "10m"
      progress_deadline = "15m"
    }

    restart {
      attempts = 3
      interval = "10m"
      delay    = "30s"
      mode     = "fail"
    }

    task "ollama" {
      driver = "podman"

      config {
        image              = "docker.io/ollama/ollama:${var.image_version}"
        image_pull_timeout = "10m"
        ports              = ["http"]
      }

      device "nvidia/gpu" {
        count = 1
      }

      env {
        OLLAMA_HOST = "0.0.0.0:${NOMAD_PORT_http}"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
