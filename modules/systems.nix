{
  config,
  inputs,
  lib,
  ...
}:
let
  nixos = config.flake.modules.nixos;
  darwin = config.flake.modules.darwin;
  users = import ../users.nix;

  hosts = [
    "infra-01"
    "deploy-01"
    "signage-01"
    "snoopy"
  ];

  darwinHosts = [
    "infra-02"
  ];

  specialArgs = { inherit inputs users; };

  modulesFor = hostname: [
    nixos.${hostname}
    nixos.global
  ];

  darwinModulesFor = hostname: [
    darwin.${hostname}
    darwin.global
  ];
in
{
  flake.nixosConfigurations = lib.genAttrs hosts (
    hostname:
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      inherit specialArgs;
      modules = modulesFor hostname;
    }
  );

  flake.darwinConfigurations = lib.genAttrs darwinHosts (
    hostname:
    inputs.nix-darwin.lib.darwinSystem {
      inherit specialArgs;
      modules = darwinModulesFor hostname;
    }
  );

  flake.colmenaHive = inputs.colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
        inherit (inputs) nix-darwin;
        nodeNixpkgs = lib.genAttrs darwinHosts (_: import inputs.nixpkgs { system = "aarch64-darwin"; });
        inherit specialArgs;
      };
    }
    // lib.genAttrs hosts (
      hostname:
      let
        bastion = config.flake.nixosConfigurations.${hostname}.config.scottylabs.bastion;
      in
      {
        deployment = {
          targetHost = "${hostname}.scottylabs.org";
          targetUser = "deploy";
          sshOptions = lib.optionals (bastion != null) [
            "-J"
            "deploy@${bastion}"
          ];
        };
        imports = modulesFor hostname;
      }
    )
    // lib.genAttrs darwinHosts (
      hostname:
      let
        bastion = config.flake.darwinConfigurations.${hostname}.config.scottylabs.bastion;
      in
      {
        deployment = {
          systemType = "darwin";
          # x86_64 deployers cannot cross-build darwin, and the mini can build itself
          buildOnTarget = true;
          targetHost = "${hostname}.scottylabs.org";
          targetUser = "deploy";
          sshOptions = lib.optionals (bastion != null) [
            "-J"
            "deploy@${bastion}"
          ];
        };
        imports = darwinModulesFor hostname;
      }
    )
  );
}
