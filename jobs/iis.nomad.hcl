job "iis" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "windows"
  }

  group "web" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name     = "iis"
      port     = "http"
      provider = "nomad"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.iis.rule=PathPrefix(`/iis`)",
        "traefik.http.routers.iis.entrypoints=web",
        "traefik.http.middlewares.iis-strip.stripprefix.prefixes=/iis",
        "traefik.http.routers.iis.middlewares=iis-strip",
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

    task "iis" {
      driver = "iis"

      config {
        application {
          path = "local"
        }

        binding {
          type = "http"
          port = "http"
        }
      }

      template {
        data        = <<-EOT
          <html><body>
          <h1>Nomad on Windows</h1>
          <p>Host: {{ env "attr.unique.hostname" }}</p>
          <p>Alloc: {{ env "NOMAD_ALLOC_ID" }}</p>
          </body></html>
        EOT
        destination = "local/index.html"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
