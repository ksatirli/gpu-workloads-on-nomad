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
      port "http" {
        static = 8080
      }
    }

    service {
      name     = "iis"
      port     = "http"
      provider = "nomad"

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

    task "setup" {
      driver    = "raw_exec"
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
          # Install IIS if not present
          if (-not (Get-WindowsFeature Web-Server).Installed) {
            Install-WindowsFeature -Name Web-Server -IncludeManagementTools
          }
          # Open firewall for the allocated port
          New-NetFirewallRule -DisplayName "Nomad IIS" -Direction Inbound -LocalPort {{ env "NOMAD_PORT_http" }} -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
        EOT
        destination = "local/setup.ps1"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    task "iis" {
      driver = "raw_exec"

      config {
        command = "powershell.exe"
        args    = ["-ExecutionPolicy", "Bypass", "-File", "${NOMAD_TASK_DIR}/run.ps1"]
      }

      template {
        data        = <<-EOT
          Import-Module WebAdministration

          Remove-WebBinding -Name 'Default Web Site' -BindingInformation '*:80:' -ErrorAction SilentlyContinue
          New-WebBinding -Name 'Default Web Site' -Protocol http -Port {{ env "NOMAD_PORT_http" }} -IPAddress '*'

          $html = "<html><body><h1>Nomad on Windows</h1><p>Host: $env:COMPUTERNAME</p><p>Alloc: $env:NOMAD_ALLOC_ID</p></body></html>"
          Set-Content -Path C:\inetpub\wwwroot\index.html -Value $html -Encoding ASCII

          # Ensure IIS is running
          Start-Service W3SVC -ErrorAction SilentlyContinue

          # Block to keep the task alive
          while ($true) { Start-Sleep -Seconds 60 }
        EOT
        destination = "local/run.ps1"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
