{ ... }:

{
  imports = [
    ./ai-gateway
    ./forgejo-ci
    ./garage
    ./matrix
    ./observability
    ./tailnet

    ./atlantis.nix
    ./postgresql.nix
    ./tofu-runner.nix
    ./uptime-kuma.nix
    ./valkey.nix
  ];
}
