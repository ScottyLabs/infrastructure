{ config, ... }:
{
  flake.modules.nixos.infra-01.imports = with config.flake.modules.nixos; [
    # Platform
    campus-cloud

    # Common
    postgresql
    server
    webadmin

    # Services
    infra-01-ai-gateway
    infra-01-atlantis
    infra-01-atlantis-service
    infra-01-bridge-media-proxy
    infra-01-cmu-vpn
    infra-01-configuration
    infra-01-forgejo
    infra-01-garage
    infra-01-grafana
    infra-01-headplane
    infra-01-headscale
    infra-01-keycloak
    infra-01-litellm
    infra-01-loki
    infra-01-matrix
    infra-01-matrix-bridge-identity
    infra-01-matrix-options
    infra-01-mautrix-discord
    infra-01-mautrix-slack
    infra-01-nixos-mautrix-slack
    infra-01-observability
    infra-01-openbao
    infra-01-prometheus
    infra-01-renovate
    infra-01-snot
    infra-01-synapse
    infra-01-tailnet
    infra-01-tempo
    infra-01-tofu-providers
    infra-01-uptime
    infra-01-uptime-kuma
    infra-01-vaultwarden
    infra-01-webhook
    infra-01-well-known
  ];
}
