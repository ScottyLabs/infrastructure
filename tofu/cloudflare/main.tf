terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "scottylabs" {
  filter = {
    name = "scottylabs.org"
  }
}

data "cloudflare_zone" "terrier_build" {
  filter = {
    name = "terrier.build"
  }
}
