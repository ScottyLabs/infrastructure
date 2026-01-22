locals {
  a_records = {
    # hosts/infra-01
    infra-01    = { ip = "128.2.25.63", comment = "https://netreg.net.cmu.edu/" }
    idp         = { ip = "128.2.25.63", comment = "Keycloak" }
    secrets2    = { ip = "128.2.25.63", comment = "OpenBao" }
    vault       = { ip = "128.2.25.63", comment = "Vaultwarden" }
    webhooks    = { ip = "128.2.25.63", comment = "Nix flake updates for infrastructure" }
    "sunlit.mc" = { ip = "128.2.25.63", comment = "Sunlit Minecraft server" }

    # hosts/prod-01
    prod-01     = { ip = "128.2.25.68", comment = "https://netreg.net.cmu.edu/" }
    verify      = { ip = "128.2.25.68", comment = "Discord Andrew ID verification bot" }

    # hosts/prod-02
    prod-02     = { ip = "128.2.25.71", comment = "https://netreg.net.cmu.edu/" }
  }
}

resource "cloudflare_record" "a" {
  for_each = local.a_records

  zone_id = data.cloudflare_zone.scottylabs.id
  name    = each.key
  content = each.value.ip
  type    = "A"
  ttl     = 1
  proxied = false
  comment = "${each.value.comment} - managed by OpenTofu"
}
