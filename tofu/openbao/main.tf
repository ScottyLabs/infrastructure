terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "vault" {
  address = "http://127.0.0.1:8200"
  # Token comes from VAULT_TOKEN env var
}
