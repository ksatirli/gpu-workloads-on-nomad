#cloud-config

# Nomad installation per https://developer.hashicorp.com/nomad/docs/deploy
apt:
  preserve_sources_list: true
  sources:
    hashicorp:
      source: "deb [signed-by=$KEY_FILE] https://apt.releases.hashicorp.com $RELEASE main"
      keyid: 798AEC654E5C15428C8E42EEAA16FCBCA621E701
      keyserver: keyserver.ubuntu.com
    nvidia-container-toolkit-amd64:
      source: "deb [signed-by=$KEY_FILE] https://nvidia.github.io/libnvidia-container/stable/deb/amd64 /"
      keyid: DDCAE044F796ECB0
      keyserver: keyserver.ubuntu.com
    nvidia-container-toolkit-arm64:
      source: "deb [signed-by=$KEY_FILE] https://nvidia.github.io/libnvidia-container/stable/deb/arm64 /"
      keyid: DDCAE044F796ECB0
      keyserver: keyserver.ubuntu.com

packages:
  - ca-certificates
  - curl
  - gnupg2
  - libnvidia-container-tools
  - libnvidia-container1
  - nomad
  - nomad-driver-podman
  - nvidia-container-toolkit
  - nvidia-container-toolkit-base
  - podman
  - unzip

write_files:
  - path: /etc/nomad.d/nomad-server.hcl
    owner: root:root
    permissions: '0644'
    encoding: b64
    content: ${nomad_server_config_b64}
  - path: /etc/nomad.d/nomad-client.hcl
    owner: root:root
    permissions: '0644'
    encoding: b64
    content: ${nomad_client_config_b64}

# Post-install: CDI for Podman, HashiCorp plugins (not in apt)
runcmd:
  # Pick server vs client config by VMSS instance ID (first N instances = servers)
  - |
    for _ in 1 2 3 4 5; do
      INSTANCE_ID=$(curl -s -H "Metadata: true" --connect-timeout 2 "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('compute',{}).get('instanceId','999'))" 2>/dev/null || echo "999")
      case "$${INSTANCE_ID}" in ''|*[!0-9]*) INSTANCE_ID=999;; esac
      [ "$${INSTANCE_ID}" != "999" ] && break
      sleep 2
    done
    if [ "$${INSTANCE_ID}" -lt "${nomad_server_count}" ]; then
      cp /etc/nomad.d/nomad-server.hcl /etc/nomad.d/nomad.hcl
    else
      cp /etc/nomad.d/nomad-client.hcl /etc/nomad.d/nomad.hcl
    fi
    rm -f /etc/nomad.d/nomad-server.hcl /etc/nomad.d/nomad-client.hcl
  - |
    mkdir -p /etc/cdi
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml || echo "nvidia-ctk cdi generate skipped (no GPU hardware)"
    rm -f /usr/share/containers/oci/hooks.d/oci-nvidia-hook.json
# nomad-autoscaler, nomad-device-nvidia, and nomad-driver-exec2 are not in apt; install from HashiCorp releases
  - |
    ARCH=$(case $(uname -m) in x86_64) echo amd64;; aarch64) echo arm64;; *) echo amd64;; esac)
    mkdir -p /opt/nomad/data/plugins
    curl -fsSLo /tmp/nomad-device-nvidia.zip "https://releases.hashicorp.com/nomad-device-nvidia/1.1.0/nomad-device-nvidia_1.1.0_linux_$${ARCH}.zip"
    unzip -o /tmp/nomad-device-nvidia.zip -d /opt/nomad/data/plugins
    chmod +x /opt/nomad/data/plugins/nomad-device-nvidia
    rm /tmp/nomad-device-nvidia.zip
  - |
    ARCH=$(case $(uname -m) in x86_64) echo amd64;; aarch64) echo arm64;; *) echo amd64;; esac)
    curl -fsSLo /tmp/nomad-driver-exec2.zip "https://releases.hashicorp.com/nomad-driver-exec2/0.1.1/nomad-driver-exec2_0.1.1_linux_$${ARCH}.zip"
    unzip -o /tmp/nomad-driver-exec2.zip -d /opt/nomad/data/plugins
    chmod +x /opt/nomad/data/plugins/nomad-driver-exec2
    rm /tmp/nomad-driver-exec2.zip
  - |
    ARCH=$(case $(uname -m) in x86_64) echo amd64;; aarch64) echo arm64;; *) echo amd64;; esac)
    curl -fsSLo /tmp/nomad-autoscaler.zip "https://releases.hashicorp.com/nomad-autoscaler/0.4.9/nomad-autoscaler_0.4.9_linux_$${ARCH}.zip"
    unzip -o /tmp/nomad-autoscaler.zip -d /usr/local/bin
    chmod +x /usr/local/bin/nomad-autoscaler
    rm /tmp/nomad-autoscaler.zip
  - systemctl enable nomad
  - systemctl start nomad
