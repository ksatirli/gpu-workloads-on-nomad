terraform {
  # see https://developer.hashicorp.com/terraform/language/block/terraform#cloud
  cloud {
    organization = "a-demo-organization"

    # optionally use `app.eu.terraform.io` for a Europe-hosted TFE instance
    hostname = "app.terraform.io"

    workspaces {
      name = "nomad-gpu-workloads"
    }
  }

  # see https://developer.hashicorp.com/terraform/language/block/terraform#required_providers
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/azurerm/4.61.0
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.61.0, < 5.0.0"
    }

    # see https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3.0, < 3.0.0"
    }

    # see https://registry.terraform.io/providers/hashicorp/http/latest/docs
    http = {
      source  = "hashicorp/http"
      version = ">= 3.5.0, < 4.0.0"
    }

    # see https://registry.terraform.io/providers/hashicorp/local/2.7.0/docs
    local = {
      source  = "hashicorp/local"
      version = ">= 2.7.0, < 3.0.0"
    }

    # see https://registry.terraform.io/providers/hashicorp/random/latest/docs
    random = {
      source  = "hashicorp/random"
      version = ">= 3.8.0, < 4.0.0"
    }

    # see https://registry.terraform.io/providers/hashicorp/tls/4.2.0/docs
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.2.0, < 5.0.0"
    }
  }

  # see https://developer.hashicorp.com/terraform/language/block/terraform#required_version
  required_version = ">= 1.14.0, < 2.0.0"
}
