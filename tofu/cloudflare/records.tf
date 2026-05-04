locals {
  a_records = {
    # hosts/infra-01
    infra-01    = { ip = "128.2.25.63", comment = "Campus Cloud VM (https://netreg.net.cmu.edu/)" }
    idp         = { ip = "128.2.25.63", comment = "Keycloak" }
    secrets2    = { ip = "128.2.25.63", comment = "OpenBao" }
    vault       = { ip = "128.2.25.63", comment = "Vaultwarden" }
    webhooks    = { ip = "128.2.25.63", comment = "Nix flake updates for infrastructure" }
    "sunlit.mc" = { ip = "128.2.25.63", comment = "Sunlit Minecraft server" }
    headscale   = { ip = "128.2.25.63", comment = "Headscale VPN coordination server" }
    headplane   = { ip = "128.2.25.63", comment = "Headplane web UI for Headscale" }
    s3          = { ip = "128.2.25.63", comment = "Garage S3-compatible object storage" }
    assets      = { ip = "128.2.25.63", comment = "Garage public-read website endpoint for the scottylabs-assets bucket" }
    garage      = { ip = "128.2.25.63", comment = "Garage web admin UI fronted by caddy with Keycloak OIDC" }
    atlantis    = { ip = "128.2.25.63", comment = "Atlantis OpenTofu PR automation" }

    # hosts/deploy-01
    deploy-01   = { ip = "128.2.25.68", comment = "Campus Cloud VM (https://netreg.net.cmu.edu/)" }
    verify      = { ip = "128.2.25.68", comment = "Discord Andrew ID verification bot" }
    bus-sign    = { ip = "128.2.25.68", comment = "CUC Bus Sign" }
    voting-app  = { ip = "128.2.25.68", comment = "Senate Voting Application" }
    mcp-server  = { ip = "128.2.25.68", comment = "ScottyLabs MCPs" }
    kennel      = { ip = "128.2.25.68", comment = "Kennel deployment platform" }

    # hosts/snoopy
    snoopy      = { ip = "128.237.157.156", comment = "Computer Club VM (g:scottylabs:snoopy)" }

    # other
    "@"         = { ip = "76.76.21.21", comment = "Vercel" }
    www         = { ip = "76.76.21.21", comment = "Vercel" }
  }
}

locals {
  doggylabs_a_records = {
    # hosts/infra-01
    "@"    = { ip = "128.2.25.63", comment = "Matrix homeserver (Synapse)" }
    matrix = { ip = "128.2.25.63", comment = "Matrix homeserver (Synapse)" }
  }
}

locals {
  terrier_build_a_records = {
    auth = { ip = "128.2.25.71", comment = "SAML proxy for university authentication" }
    docs = { ip = "128.2.25.71", comment = "Terrier documentation" }
  }
}

resource "cloudflare_dns_record" "kennel_wildcard" {
  zone_id = data.cloudflare_zone.scottylabs_net.zone_id
  name    = "*"
  content = "128.2.25.68"
  type    = "A"
  ttl     = 1
  proxied = false
  comment = "Kennel deployment platform wildcard - managed by OpenTofu"
}

resource "cloudflare_dns_record" "a" {
  for_each = local.a_records

  zone_id = data.cloudflare_zone.scottylabs.zone_id
  name    = each.key
  content = each.value.ip
  type    = "A"
  ttl     = 1
  proxied = false
  comment = "${each.value.comment} - managed by OpenTofu"
}

resource "cloudflare_dns_record" "doggylabs_a" {
  for_each = local.doggylabs_a_records

  zone_id = data.cloudflare_zone.doggylabs.zone_id
  name    = each.key
  content = each.value.ip
  type    = "A"
  ttl     = 1
  proxied = false
  comment = "${each.value.comment} - managed by OpenTofu"
}

resource "cloudflare_dns_record" "terrier_build_a" {
  for_each = local.terrier_build_a_records

  zone_id = data.cloudflare_zone.terrier_build.zone_id
  name    = each.key
  content = each.value.ip
  type    = "A"
  ttl     = 1
  proxied = false
  comment = "${each.value.comment} - managed by OpenTofu"
}
