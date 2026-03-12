# GPU Workloads on Nomad

HashiCorp Nomad cluster on Azure with GPU support, mixed Linux/Windows workloads, and automatic scaling.

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

### Check current quota

```bash
az vm list-usage --location <region> -o table | grep "NCASv3_T4"
```

