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

  hosts = {
    infra-01 = "x86_64-linux";
    infra-03 = "aarch64-linux";
    deploy-01 = "x86_64-linux";
    signage-01 = "x86_64-linux";
    snoopy = "x86_64-linux";
  };

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
  flake.nixosConfigurations = lib.mapAttrs (
    hostname: system:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      inherit specialArgs;
      modules = modulesFor hostname;
    }
  ) hosts;

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
        nodeNixpkgs =
          lib.genAttrs darwinHosts (_: import inputs.nixpkgs { system = "aarch64-darwin"; })
          // lib.mapAttrs (_: system: import inputs.nixpkgs { inherit system; }) (
            lib.filterAttrs (_: system: system != "x86_64-linux") hosts
          );
        inherit specialArgs;
      };
    }
    // lib.genAttrs (lib.attrNames hosts) (
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
