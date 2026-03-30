terraform {
  required_providers {
    garage = {
      source  = "Arsolitt/garagehq"
      version = "~> 0.1"
    }
  }
}

provider "garage" {
  host   = "127.0.0.1:3903"
  scheme = "http"
  token  = var.garage_admin_token
}
