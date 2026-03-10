variable "rcon_password" {
  type        = string
  default     = "nomad-minecraft"
  description = "RCON password for remote console access to the Minecraft server."
}

# Minecraft Java Edition Server (containerized)
job "minecraft-java" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "linux"
  }

  group "server" {
    count = 1

    network {
      port "game" {
        static = 25565
      }
      port "rcon" {
        static = 25575
      }
    }

    service {
      name     = "minecraft-java"
      port     = "game"
      provider = "nomad"

      check {
        type     = "tcp"
        interval = "30s"
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

    task "minecraft" {
      driver = "podman"

      config {
        image              = "docker.io/itzg/minecraft-server:2026.1.3"
        image_pull_timeout = "10m"
        ports              = ["game", "rcon"]
      }

      env {
        EULA              = "TRUE"
        SERVER_PORT       = "${NOMAD_PORT_game}"
        RCON_PORT         = "${NOMAD_PORT_rcon}"
        RCON_PASSWORD     = var.rcon_password
        MOTD              = "Nomad GPU Workloads - Java Edition"
        MAX_PLAYERS       = "20"
        DIFFICULTY        = "normal"
        MODE              = "survival"
        VIEW_DISTANCE     = "10"
        MEMORY            = "2G"
        TYPE              = "VANILLA"
        ENABLE_RCON       = "true"
        ONLINE_MODE       = "true"
      }

      resources {
        cpu    = 1500
        memory = 2560
      }
    }
  }
}
