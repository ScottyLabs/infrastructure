{ ... }:

{
  imports = [
    ./forgejo-ci
    ./garage
    ./matrix
    ./observability
    ./tailnet
    ./atlantis.nix
    ./litellm.nix
    ./postgresql.nix
    ./tofu-runner.nix
    ./uptime-kuma.nix
    ./valkey.nix
  ];
}
