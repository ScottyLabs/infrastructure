terraform {
  required_providers {
    garage = {
      source  = "registry.terraform.io/henrywhitaker3/garage"
      version = "~> 1.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "garage" {
  host   = "127.0.0.1:3903"
  scheme = "http"
  token  = var.garage_admin_token
}

provider "vault" {
  address = "http://127.0.0.1:8200"
  # Token comes from VAULT_TOKEN env var
}
