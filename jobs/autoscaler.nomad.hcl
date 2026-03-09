# Nomad Autoscaler - cluster and horizontal application scaling
# see https://developer.hashicorp.com/nomad/tools/autoscaling
job "autoscaler" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${node.class}"
    value     = "linux"
  }

  group "autoscaler" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name     = "autoscaler"
      port     = "http"
      provider = "nomad"

      check {
        type     = "http"
        path     = "/v1/health"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "autoscaler" {
      driver = "exec"

      config {
        command = "/usr/local/bin/nomad-autoscaler"
        args    = ["agent", "-config", "${NOMAD_TASK_DIR}/config.hcl"]
      }

      template {
        data = <<-EOT
          nomad {
            address = "http://{{env "attr.unique.network.ip-address"}}:4646"
            token   = "{{ with nomadVar "nomad/jobs/autoscaler" }}{{ .nomad_token }}{{ end }}"
          }

          http {
            bind_address = "0.0.0.0"
            bind_port    = {{env "NOMAD_PORT_http"}}
          }

          telemetry {
            prometheus_metrics = true
          }

          policy_eval {
            workers = {
              cluster    = 2
              horizontal = 2
            }
          }

          apm "nomad-apm" {
            driver = "nomad-apm"
          }

          target "nomad-target" {
            driver = "nomad-target"
          }

          # Azure VMSS target for cluster scaling
          # see https://developer.hashicorp.com/nomad/tools/autoscaling/plugins/target/azure-vmss
          target "azure-vmss" {
            driver = "azure-vmss"
            config = {
              tenant_id         = "{{ with nomadVar "nomad/jobs/autoscaler" }}{{ .tenant_id }}{{ end }}"
              client_id         = "{{ with nomadVar "nomad/jobs/autoscaler" }}{{ .client_id }}{{ end }}"
              secret_access_key = "{{ with nomadVar "nomad/jobs/autoscaler" }}{{ .secret_access_key }}{{ end }}"
              subscription_id   = "{{ with nomadVar "nomad/jobs/autoscaler" }}{{ .subscription_id }}{{ end }}"
            }
          }

          strategy "target-value" {
            driver = "target-value"
          }
        EOT

        destination = "local/config.hcl"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
