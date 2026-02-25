# Install Nomad on Windows - HashiCorp Nomad client
$ErrorActionPreference = "Stop"
$NOMAD_VERSION = "1.11.2"
$NOMAD_URL = "https://releases.hashicorp.com/nomad/$NOMAD_VERSION/nomad_$NOMAD_VERSION`_windows_amd64.zip"
$INSTALL_DIR = "C:\Program Files\Nomad"
$DATA_DIR = "C:\ProgramData\Nomad\data"
$CONFIG_DIR = "C:\ProgramData\Nomad"
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

# Install and start Nomad as Windows service
& $nomadPath windows service install -config=$CONFIG_FILE
Start-Service -Name "Nomad"
