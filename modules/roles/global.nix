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
        cloudflared
        ip-address
        ncro
        node-exporter
        observability-agents
        otel-collector
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

  # Base layer composed onto every darwin host
  flake.modules.darwin.global =
    { pkgs, ... }:
    {
      imports = [
        config.flake.modules.darwin.ip-address
        config.flake.modules.darwin.shell
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];

      # Nix
      nix.package = pkgs.lixPackageSets.stable.lix;
      nix.settings.experimental-features = "nix-command flakes";

      # Set Git commit hash for darwin-version
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    };
}
