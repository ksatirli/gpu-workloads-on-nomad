job "minecraft-bedrock" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "windows"
  }

  group "server" {
    count = 1

    network {
      port "ipv4" {
        static = 19132
      }
      port "ipv6" {
        static = 19133
      }
    }

    service {
      name     = "minecraft-bedrock"
      port     = "ipv4"
      provider = "nomad"
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

    task "setup" {
      driver = "raw_exec"
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        command = "powershell.exe"
        args    = ["-ExecutionPolicy", "Bypass", "-File", "${NOMAD_TASK_DIR}/setup.ps1"]
      }

      template {
        data        = <<-EOT
          $ServerDir = "{{ env "NOMAD_ALLOC_DIR" }}\minecraft-bedrock"
          New-Item -ItemType Directory -Force -Path $ServerDir | Out-Null

          $vcInstalled = Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
          if (-not $vcInstalled) {
            Write-Output "Installing Visual C++ Redistributable..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            $vcExe = "$env:TEMP\vc_redist.x64.exe"
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcExe -UseBasicParsing
            Start-Process -FilePath $vcExe -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Remove-Item $vcExe -Force
          }

          $exePath = "$ServerDir\bedrock_server.exe"
          if (-not (Test-Path $exePath)) {
            Write-Output "Downloading Minecraft Bedrock Dedicated Server..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $zipPath = "$env:TEMP\bedrock-server.zip"
            # Bedrock server download requires accepting the EULA via user-agent header
            $url = "https://www.minecraft.net/bedrockdedicatedserver/bin-win/bedrock-server-1.21.51.02.zip"
            $headers = @{ "User-Agent" = "Mozilla/5.0" }
            try {
              Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -Headers $headers
            } catch {
              # Fallback: try fetching the download page to find the latest URL
              Write-Output "Direct download failed, trying latest version lookup..."
              $page = Invoke-WebRequest -Uri "https://www.minecraft.net/en-us/download/server/bedrock" -UseBasicParsing -Headers $headers
              $match = [regex]::Match($page.Content, 'https://www\.minecraft\.net/bedrockdedicatedserver/bin-win/bedrock-server-[\d\.]+\.zip')
              if ($match.Success) {
                Invoke-WebRequest -Uri $match.Value -OutFile $zipPath -UseBasicParsing -Headers $headers
              } else {
                Write-Error "Could not find Bedrock server download URL"
                exit 1
              }
            }
            Write-Output "Extracting..."
            Expand-Archive -Path $zipPath -DestinationPath $ServerDir -Force
            Remove-Item $zipPath -Force
          }

          $props = @"
          server-name=Nomad GPU Workloads - Bedrock
          gamemode=survival
          difficulty=normal
          max-players=20
          online-mode=true
          server-port={{ env "NOMAD_PORT_ipv4" }}
          server-portv6={{ env "NOMAD_PORT_ipv6" }}
          view-distance=10
          level-name=Bedrock Level
          "@
          Set-Content -Path "$ServerDir\server.properties" -Value ($props -replace '^\s+','') -Encoding ASCII

          # Open firewall for UDP (Bedrock uses UDP for game traffic)
          New-NetFirewallRule -DisplayName "Minecraft Bedrock UDP" -Direction Inbound -LocalPort {{ env "NOMAD_PORT_ipv4" }} -Protocol UDP -Action Allow -ErrorAction SilentlyContinue
          New-NetFirewallRule -DisplayName "Minecraft Bedrock UDP6" -Direction Inbound -LocalPort {{ env "NOMAD_PORT_ipv6" }} -Protocol UDP -Action Allow -ErrorAction SilentlyContinue

          Write-Output "Setup complete"
        EOT
        destination = "local/setup.ps1"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    task "bedrock" {
      driver = "raw_exec"

      config {
        command = "powershell.exe"
        args    = ["-ExecutionPolicy", "Bypass", "-File", "${NOMAD_TASK_DIR}/run.ps1"]
      }

      template {
        data        = <<-EOT
          $ServerDir = "{{ env "NOMAD_ALLOC_DIR" }}\minecraft-bedrock"
          Set-Location $ServerDir
          & "$ServerDir\bedrock_server.exe"
        EOT
        destination = "local/run.ps1"
      }

      resources {
        cpu    = 1000
        memory = 1536
      }
    }
  }
}
