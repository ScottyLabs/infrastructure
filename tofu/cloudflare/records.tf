locals {
  a_records = {
    # hosts/infra-01
    infra-01    = { ip = "128.2.25.63", comment = "Campus Cloud VM (https://netreg.net.cmu.edu/)" }
    idp         = { ip = "128.2.25.63", comment = "Keycloak" }
    secrets2    = { ip = "128.2.25.63", comment = "OpenBao" }
    vault       = { ip = "128.2.25.63", comment = "Vaultwarden" }
    webhooks    = { ip = "128.2.25.63", comment = "Nix flake updates for infrastructure" }
    headscale   = { ip = "128.2.25.63", comment = "Headscale VPN coordination server" }
    headplane   = { ip = "128.2.25.63", comment = "Headplane web UI for Headscale" }
    s3          = { ip = "128.2.25.63", comment = "Garage S3-compatible object storage" }
    assets      = { ip = "128.2.25.63", comment = "Garage public-read website endpoint for the scottylabs-assets bucket" }
    cdn         = { ip = "128.2.25.63", comment = "Garage public-read CDN" }
    docs        = { ip = "128.2.25.63", comment = "ScottyLabs documentation hub (Garage scottylabs-docs bucket)" }
    garage      = { ip = "128.2.25.63", comment = "Garage web admin UI fronted by caddy with Keycloak OIDC" }
    atlantis    = { ip = "128.2.25.63", comment = "Atlantis OpenTofu PR automation" }
    grafana     = { ip = "128.2.25.63", comment = "Grafana observability frontend" }
    uptime      = { ip = "128.2.25.63", comment = "Uptime Kuma public status page" }
    litellm     = { ip = "128.2.25.63", comment = "LiteLLM AI gateway fronting cli-proxy-api" }

    # hosts/deploy-01
    deploy-01   = { ip = "128.2.25.68", comment = "Campus Cloud VM (https://netreg.net.cmu.edu/)" }
    kennel      = { ip = "128.2.25.68", comment = "Kennel deployment platform" }
    oauth       = { ip = "128.2.25.68", comment = "Ricochet OAuth callback relay" }
    "s3.kennel" = { ip = "128.2.25.68", comment = "Kennel per-deployment garage S3 API" }

    # hosts/snoopy
    snoopy      = { ip = "128.237.157.156", comment = "Computer Club VM (g:scottylabs:snoopy)" }

    # hosts/bus-sign-display
    mele-cyber-x1 = { ip = "172.26.173.66", comment = "Mele Cyber X1 bus sign display" }
  }
}

locals {
  doggylabs_a_records = {
    # hosts/infra-01
    "@"    = { ip = "128.2.25.63", comment = "Matrix homeserver (Synapse)" }
    matrix = { ip = "128.2.25.63", comment = "Matrix homeserver (Synapse)" }
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

resource "cloudflare_dns_record" "posthog_reverse_proxy" {
  zone_id = data.cloudflare_zone.scottylabs.zone_id
  name    = "v"
  content = "1e191a7f16b24e2e436f.cf-prod-us-proxy.proxyhog.com"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  comment = "PostHog managed reverse proxy - managed by OpenTofu"
}
