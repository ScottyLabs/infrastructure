terraform {
  required_providers {
    garage = {
      source  = "registry.terraform.io/jkossis/garage"
      version = "~> 1.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "garage" {
  endpoint = "http://127.0.0.1:3903"
  token    = var.garage_admin_token
}

provider "vault" {
  address = "http://127.0.0.1:8200"
  # Token comes from VAULT_TOKEN env var
}
