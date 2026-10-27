{ config, ... }:
{
  flake.modules.nixos.scottylabs-infra-01.imports = with config.flake.modules.nixos; [
    # Platform
    campus-cloud

    # Common
    postgresql
    server
    webadmin

    # Services
    scottylabs-infra-01-ai-gateway
    scottylabs-infra-01-atlantis
    scottylabs-infra-01-atlantis-service
    scottylabs-infra-01-bridge-media-proxy
    scottylabs-infra-01-cmu-vpn
    scottylabs-infra-01-configuration
    scottylabs-infra-01-darwin-builder
    scottylabs-infra-01-forgejo
    scottylabs-infra-01-garage
    scottylabs-infra-01-grafana
    scottylabs-infra-01-headplane
    scottylabs-infra-01-headscale
    scottylabs-infra-01-keycloak
    scottylabs-infra-01-litellm
    scottylabs-infra-01-loki
    scottylabs-infra-01-matrix
    scottylabs-infra-01-matrix-bridge-identity
    scottylabs-infra-01-matrix-options
    scottylabs-infra-01-mautrix-discord
    scottylabs-infra-01-mautrix-slack
    scottylabs-infra-01-nixbot
    scottylabs-infra-01-nixbuild
    scottylabs-infra-01-nixos-mautrix-slack
    scottylabs-infra-01-observability
    scottylabs-infra-01-openbao
    scottylabs-infra-01-prometheus
    scottylabs-infra-01-renovate
    scottylabs-infra-01-snot
    scottylabs-infra-01-synapse
    scottylabs-infra-01-tailnet
    scottylabs-infra-01-tempo
    scottylabs-infra-01-tofu-providers
    scottylabs-infra-01-uptime
    scottylabs-infra-01-uptime-kuma
    scottylabs-infra-01-vaultwarden
    scottylabs-infra-01-webhook
    scottylabs-infra-01-well-known
  ];
}
