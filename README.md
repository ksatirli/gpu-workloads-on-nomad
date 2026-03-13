# GPU Workloads on Nomad

HashiCorp Nomad cluster on Azure with GPU support, mixed Linux/Windows workloads, and automatic scaling.

## Architecture

```mermaid
graph TB
    subgraph Internet
        User([User / Player])
    end

    subgraph Azure["Azure (Resource Group: nomad-gpu)"]

        subgraph Networking["Networking"]
            PIP[Public IP]
            NAT[NAT Gateway]
            Bastion[Azure Bastion]
        end

        subgraph PublicLB["Public Load Balancer"]
            LB80[":80 HTTP"]
            LB8080[":8080 Traefik Dashboard"]
            LB4646[":4646 Nomad API"]
            LB25565[":25565 Minecraft Java"]
            LB19132[":19132/udp Minecraft Bedrock"]
        end

        subgraph VNet["VNet 10.0.0.0/16"]

            subgraph Subnet["VMSS Subnet 10.0.1.0/24"]

                subgraph LinuxVMSS["Linux VMSS (Ubuntu 24.04)"]
                    subgraph Servers["Nomad Servers (instances 0-2)"]
                        S1[Server 1]
                        S2[Server 2]
                        S3[Server 3]
                    end

                    subgraph Clients["Nomad Clients (instances 3+)"]
                        direction TB
                        GPU["NVIDIA GPU Driver (optional N-series)"]
                        NvidiaPlugin["nomad-device-nvidia"]
                        Podman["Podman + NVIDIA Container Toolkit"]

                        subgraph LinuxJobs["Linux Workloads"]
                            Traefik["Traefik (system job)\n:80 :8080"]
                            Ollama["Ollama\nLLM Inference"]
                            Docling["Docling\nDocument AI\n(autoscaled 1-3)"]
                            MCJava["Minecraft Java\n:25565"]
                            Autoscaler["Nomad Autoscaler"]
                        end
                    end
                end

                ILB["Internal LB\n10.0.1.10\n:4647 :4648"]

                subgraph WindowsVM["Windows VM (Server 2025)"]
                    WinNomad["Nomad Client\nnode_class=windows"]
                    IISDriver["nomad-iis driver"]
                    RawExec["raw_exec driver"]
                    JavaJRE["OpenJDK 21 JRE"]

                    subgraph WinJobs["Windows Workloads"]
                        IIS["IIS Web Server"]
                        MCBedrock["Minecraft Bedrock\n:19132/udp"]
                    end
                end
            end
        end

        LogAnalytics["Log Analytics\n+ Azure Monitor"]
        Storage["Storage Account\nBoot Diagnostics"]
    end

    %% Internet to LB
    User --> PIP
    PIP --> PublicLB

    %% LB to backends
    LB80 --> Traefik
    LB8080 --> Traefik
    LB4646 --> Servers
    LB25565 --> MCJava
    LB19132 --> MCBedrock

    %% Traefik routing
    Traefik -. "/iis" .-> IIS
    Traefik -. "/ollama" .-> Ollama
    Traefik -. "/" .-> Docling

    %% Internal LB for Windows server discovery
    ILB --> Servers
    WinNomad --> ILB

    %% GPU stack
    GPU --> NvidiaPlugin
    NvidiaPlugin --> Podman
    Podman --> LinuxJobs

    %% Outbound
    LinuxVMSS --> NAT
    WindowsVM --> NAT
    NAT --> Internet

    %% Monitoring
    LinuxVMSS -.-> LogAnalytics
    WindowsVM -.-> LogAnalytics
    LinuxVMSS -.-> Storage
    WindowsVM -.-> Storage

    %% Autoscaler targets
    Autoscaler -. "scale jobs" .-> Servers
    Autoscaler -. "scale VMSS" .-> LinuxVMSS

    %% Bastion
    Bastion -. "SSH/RDP" .-> Subnet

    %% Styles
    classDef gpu fill:#76b900,stroke:#333,color:#fff
    classDef windows fill:#0078d4,stroke:#333,color:#fff
    classDef linux fill:#e95420,stroke:#333,color:#fff
    classDef lb fill:#f5a623,stroke:#333,color:#fff
    classDef monitoring fill:#666,stroke:#333,color:#fff

    class GPU,NvidiaPlugin,Podman gpu
    class WindowsVM,WinNomad,IISDriver,RawExec,JavaJRE,IIS,MCBedrock windows
    class LinuxVMSS,Servers,Clients,S1,S2,S3 linux
    class PublicLB,ILB,LB80,LB8080,LB4646,LB25565,LB19132 lb
    class LogAnalytics,Storage monitoring
```

## Endpoints

| Service | URL |
|---------|-----|
| Traefik HTTP | `http://<public-ip>` |
| Traefik Dashboard | `http://<public-ip>:8080` |
| IIS (via Traefik) | `http://<public-ip>/iis` |
| Ollama (via Traefik) | `http://<public-ip>/ollama` |
| Docling (via Traefik) | `http://<public-ip>/` |
| Nomad API / UI | `http://<public-ip>:4646` |
| Minecraft Java | `<public-ip>:25565` |
| Minecraft Bedrock | `<public-ip>:19132` (UDP) |

Run `terraform output load_balancer_endpoints` to get the actual URLs.

## GPU Quota

The GPU VMSS (`var.azurerm_vmss_gpu_enabled = true`) requires N-series VM quota, which is **zero by default** on most Azure subscriptions. You must request an increase before `terraform apply` will succeed.

### Check current quota

```bash
az vm list-usage --location <region> -o table | grep "NCASv3_T4"
```

### Request quota increase via CLI

First, register the quota provider (one-time):

```bash
az provider register --namespace Microsoft.Quota
az provider show -n Microsoft.Quota --query "registrationState"  # wait for "Registered"
```

Find the exact resource name for your GPU family:

```bash
az quota list \
  --scope "/subscriptions/<subscription-id>/providers/Microsoft.Compute/locations/<region>" \
  --query "[?contains(name, 'T4')]" -o table
```

Request the increase (4 vCPUs for a single `Standard_NC4as_T4_v3`):

```bash
az quota create \
  --resource-name "Standard NCASv3_T4 Family" \
  --scope "/subscriptions/<subscription-id>/providers/Microsoft.Compute/locations/<region>" \
  --limit-object value=4 \
  --resource-type dedicated
```

### Request quota increase via Azure Portal

1. Go to **Subscriptions** > your subscription > **Usage + quotas**
2. Search for the GPU family (e.g. `NCASv3_T4`)
3. Select the region and click **Request increase**
4. Set the new limit (e.g. 4 vCPUs) and submit

Approval is typically instant for small requests, but may take up to 72 hours.
