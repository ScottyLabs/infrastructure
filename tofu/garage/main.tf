terraform {
  required_providers {
    garage = {
      source  = "registry.terraform.io/henrywhitaker3/garage"
      version = "~> 1.0"
    }
  }
}

provider "garage" {
  host   = "127.0.0.1:3903"
  scheme = "http"
  token  = var.garage_admin_token
}
