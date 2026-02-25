# Install Nomad on Windows - HashiCorp Nomad client
$ErrorActionPreference = "Stop"
$NOMAD_VERSION = "1.11.2"
$NOMAD_URL = "https://releases.hashicorp.com/nomad/$NOMAD_VERSION/nomad_$NOMAD_VERSION`_windows_amd64.zip"
# Use path without spaces to avoid Windows service path resolution issues
$INSTALL_DIR = "C:\Nomad\bin"
$DATA_DIR = "C:\Nomad\data"
$CONFIG_DIR = "C:\Nomad\config"
$CONFIG_FILE = "$CONFIG_DIR\nomad-client.hcl"

# Create directories
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $DATA_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $CONFIG_DIR | Out-Null

# Download and extract Nomad
$zipPath = "$env:TEMP\nomad.zip"
Invoke-WebRequest -Uri $NOMAD_URL -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $INSTALL_DIR -Force
Remove-Item $zipPath -Force

# Add to PATH
$nomadPath = "$INSTALL_DIR\nomad.exe"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$INSTALL_DIR", [EnvironmentVariableTarget]::Machine)
$env:Path += ";$INSTALL_DIR"

# Write Nomad client config (single-quote here-string to avoid PowerShell variable expansion)
@'
${nomad_client_config}
'@ | Set-Content -Path $CONFIG_FILE -Encoding UTF8

# Register Nomad as Windows service using sc.exe (more reliable than nomad windows service install)
# Remove existing service if present (e.g. from failed previous run)
$svc = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
if ($svc) { sc.exe delete "Nomad"; Start-Sleep -Seconds 2 }
sc.exe create "Nomad" binPath= "`"$nomadPath`" agent -config-dir=`"$CONFIG_DIR`"" start= auto
Start-Service -Name "Nomad"
