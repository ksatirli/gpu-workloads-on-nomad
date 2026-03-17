# Install Nomad on Windows - HashiCorp Nomad client
$ErrorActionPreference = "Stop"
$NOMAD_VERSION = "${nomad_version}"
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

# Download and extract Nomad (skip if already installed at the correct version)
$nomadPath = "$INSTALL_DIR\nomad.exe"
$needsInstall = $true
if (Test-Path $nomadPath) {
  $currentVersion = (& $nomadPath version 2>&1) -replace '^Nomad v','' -replace '\s.*',''
  if ($currentVersion -eq $NOMAD_VERSION) { $needsInstall = $false }
}
if ($needsInstall) {
  Stop-Service -Name "Nomad" -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  $zipPath = "$env:TEMP\nomad.zip"
  Invoke-WebRequest -Uri $NOMAD_URL -OutFile $zipPath -UseBasicParsing
  Expand-Archive -Path $zipPath -DestinationPath $INSTALL_DIR -Force
  Remove-Item $zipPath -Force
}

# Add to PATH
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$INSTALL_DIR", [EnvironmentVariableTarget]::Machine)
$env:Path += ";$INSTALL_DIR"

# Write Nomad client config (single-quote here-string to avoid PowerShell variable expansion)
@'
${nomad_client_config}
'@ | Out-File -FilePath $CONFIG_FILE -Encoding ASCII

$JAVA_DIR = "C:\Java"
$JAVA_VERSION = "${java_jre.version}"
$JAVA_SHA256 = "${java_jre.sha256}"
if (-not (Test-Path "$JAVA_DIR\bin\java.exe")) {
  New-Item -ItemType Directory -Force -Path $JAVA_DIR | Out-Null
  $jdkUrl = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${replace(java_jre.version, "+", "%2B")}/${java_jre.filename}"
  $jdkZip = "$env:TEMP\java21.zip"
  Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZip -UseBasicParsing
  $fileHash = (Get-FileHash -Path $jdkZip -Algorithm SHA256).Hash
  if ($fileHash -ne $JAVA_SHA256) {
    Remove-Item $jdkZip -Force
    throw "Java JRE checksum mismatch! Expected: $JAVA_SHA256 Got: $fileHash"
  }
  Expand-Archive -Path $jdkZip -DestinationPath "$env:TEMP\java21" -Force
  # The archive extracts into a versioned subdirectory; move contents up
  $extracted = Get-ChildItem "$env:TEMP\java21" | Select-Object -First 1
  Copy-Item -Path "$($extracted.FullName)\*" -Destination $JAVA_DIR -Recurse -Force
  Remove-Item $jdkZip -Force
  Remove-Item "$env:TEMP\java21" -Recurse -Force
  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$JAVA_DIR\bin", [EnvironmentVariableTarget]::Machine)
  $env:Path += ";$JAVA_DIR\bin"
}

# Install Visual C++ Redistributable (required by Minecraft Bedrock and other native workloads)
$vcInstalled = Test-Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
if (-not $vcInstalled) {
  $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
  $vcExe = "$env:TEMP\vc_redist.x64.exe"
  Invoke-WebRequest -Uri $vcUrl -OutFile $vcExe -UseBasicParsing
  Start-Process -FilePath $vcExe -ArgumentList "/install", "/quiet", "/norestart" -Wait
  Remove-Item $vcExe -Force
}

# Install nomad-iis task driver plugin
$PLUGIN_DIR = "C:\Nomad\plugins"
$NOMAD_IIS_VERSION = "${nomad_iis_version}"
$NOMAD_IIS_SHA256 = "${nomad_iis_sha256}"
New-Item -ItemType Directory -Force -Path $PLUGIN_DIR | Out-Null
if (-not (Test-Path "$PLUGIN_DIR\nomad_iis.exe")) {
  $iisZip = "$env:TEMP\nomad_iis.zip"
  Invoke-WebRequest -Uri "https://github.com/sevensolutions/nomad-iis/releases/download/v$NOMAD_IIS_VERSION/nomad_iis.zip" -OutFile $iisZip -UseBasicParsing

  # Verify SHA256 hash of downloaded nomad-iis plugin if an expected hash is provided
  if ($NOMAD_IIS_SHA256 -and $NOMAD_IIS_SHA256.Trim() -ne "") {
    $computedHash = (Get-FileHash -Path $iisZip -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $NOMAD_IIS_SHA256.Trim().ToLowerInvariant()
    if ($computedHash -ne $expectedHash) {
      Remove-Item $iisZip -Force -ErrorAction SilentlyContinue
      throw "SHA256 verification failed for nomad_iis.zip. Expected $expectedHash but got $computedHash."
    }
  }

  Expand-Archive -Path $iisZip -DestinationPath $PLUGIN_DIR -Force
  Remove-Item $iisZip -Force
}

# Install IIS Windows feature (required by nomad-iis driver)
if (-not (Get-WindowsFeature Web-Server).Installed) {
  Install-WindowsFeature -Name Web-Server -IncludeManagementTools
}

# Open Windows Firewall for Nomad ports (HTTP API, RPC, Serf)
New-NetFirewallRule -DisplayName "Nomad HTTP" -Direction Inbound -LocalPort 4646 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Nomad RPC" -Direction Inbound -LocalPort 4647 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Nomad Serf TCP" -Direction Inbound -LocalPort 4648 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Nomad Serf UDP" -Direction Inbound -LocalPort 4648 -Protocol UDP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Nomad Dynamic Ports" -Direction Inbound -LocalPort 20000-32000 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

# Register Nomad as Windows service using sc.exe (more reliable than nomad windows service install)
# Remove existing service if present (e.g. from failed previous run)
$svc = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
if ($svc) { sc.exe delete "Nomad"; Start-Sleep -Seconds 2 }
sc.exe create "Nomad" binPath= "`"$nomadPath`" agent -config=`"$CONFIG_DIR`"" start= auto
sc.exe failure "Nomad" reset= 86400 actions= restart/5000/restart/10000/restart/30000

# Start the service but don't fail the script if servers aren't reachable yet.
# The restart-on-failure policy will keep retrying automatically.
Start-Service -Name "Nomad" -ErrorAction SilentlyContinue
