{ config, inputs, ... }:
{
  # Base layer composed onto every host
  flake.modules.nixos.global = {
    imports =
      (with config.flake.modules.nixos; [
        acme
        alloy
        base
        btrfs
        caddy
        cadvisor
        ncro
        node-exporter
        observability-agents
        otel-collector
        public-ip
        shell
        systemd-exporter
        systemd-vaultd
        tailnet-client
      ])
      ++ [
        inputs.home-manager.nixosModules.home-manager
        inputs.agenix.nixosModules.default
        inputs.disko.nixosModules.disko

        inputs.srvos.nixosModules.server
        inputs.srvos.nixosModules.mixins-terminfo
        inputs.srvos.nixosModules.mixins-trusted-nix-caches
        { srvos.flake = inputs.self; }
      ];
  };
}
