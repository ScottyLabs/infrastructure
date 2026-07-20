{
  config,
  inputs,
  lib,
  ...
}:
let
  nixos = config.flake.modules.nixos;
  users = import ../users.nix;

  hosts = [
    "infra-01"
    "deploy-01"
    "signage-01"
    "snoopy"
  ];

  specialArgs = { inherit inputs users; };

  modulesFor = hostname: [
    nixos.${hostname}
    nixos.global
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

  flake.colmenaHive = inputs.colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
        inherit specialArgs;
      };
    }
    // lib.genAttrs hosts (hostname: {
      deployment = {
        targetHost = "${hostname}.scottylabs.org";
        targetUser = "deploy";
      };
      imports = modulesFor hostname;
    })
  );
}
