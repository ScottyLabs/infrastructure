terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = "scottylabs.org"
}

provider "vault" {
  address = "http://127.0.0.1:8200"
  # Token comes from VAULT_TOKEN env var
}

# ACL policy
resource "tailscale_acl" "policy" {
  acl = jsonencode({
    tagOwners = {
      "tag:server" = ["admin+tailscale@scottylabs.org"]
    }

    acls = [
      {
        action = "accept"
        src    = ["*"]
        dst    = ["*:*"]
      }
    ]

    ssh = [
      {
        action = "accept"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self", "tag:server"]
        users  = ["autogroup:nonroot", "root"]
      }
    ]

    autoApprovers = {
      exitNode = ["tag:server"]
    }
  })

  overwrite_existing_content = true
}

# Generate a reusable auth key for servers
resource "tailscale_tailnet_key" "server" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000  # 90 days (max)
  description   = "NixOS servers"
  tags          = ["tag:server"]

  depends_on = [tailscale_acl.policy]
}

resource "vault_kv_secret_v2" "tailscale" {
  mount = "secret"
  name  = "infra/tailscale"

  data_json = jsonencode({
    TS_AUTHKEY = tailscale_tailnet_key.server.key
  })
}
