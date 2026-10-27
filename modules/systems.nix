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
    scottylabs = {
      infra-01 = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
      infra-02 = {
        domain = "scottylabs.org";
        system = "aarch64-darwin";
      };
      infra-03 = {
        domain = "scottylabs.org";
        system = "aarch64-linux";
      };
      deploy-01 = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
      signage-01 = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
      snoopy = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
    };
    stugov = {
      elect-01 = {
        domain = "andrew.cmu.edu";
        system = "x86_64-linux";
      };
    };
    thetartan = {
      www-04 = {
        domain = "thetartan.org";
        system = "x86_64-linux";
      };
    };
  };

  allHosts = lib.concatMapAttrs (
    org:
    lib.mapAttrs' (
      name: host:
      lib.nameValuePair "${org}-${name}" (
        host
        // {
          inherit org name;
          fqdn = "${name}.${host.domain}";
        }
      )
    )
  ) hosts;

  isDarwin = host: lib.hasSuffix "-darwin" host.system;
  nixosHosts = lib.filterAttrs (_: host: !isDarwin host) allHosts;
  darwinHosts = lib.filterAttrs (_: isDarwin) allHosts;

  specialArgs = { inherit inputs users; };

  identity = host: {
    networking.hostName = host.name;
    scottylabs.organization = host.org;
    scottylabs.domain = host.domain;
  };

  modulesFor = id: host: [
    nixos.${id}
    nixos.global
    (identity host)
  ];

  darwinModulesFor = id: host: [
    darwin.${id}
    darwin.global
    (identity host)
  ];

  deploymentFor = host: bastion: {
    targetHost = host.fqdn;
    targetUser = "deploy";
    sshOptions = lib.optionals (bastion != null) [
      "-J"
      "deploy@${bastion}"
    ];
  };
in
{
  flake.nixosConfigurations = lib.mapAttrs (
    id: host:
    inputs.nixpkgs.lib.nixosSystem {
      inherit (host) system;
      inherit specialArgs;
      modules = modulesFor id host;
    }
  ) nixosHosts;

  flake.darwinConfigurations = lib.mapAttrs (
    id: host:
    inputs.nix-darwin.lib.darwinSystem {
      inherit specialArgs;
      modules = darwinModulesFor id host;
    }
  ) darwinHosts;

  flake.colmenaHive = inputs.colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
        inherit (inputs) nix-darwin;
        nodeNixpkgs = lib.mapAttrs (_: host: import inputs.nixpkgs { inherit (host) system; }) (
          lib.filterAttrs (_: host: host.system != "x86_64-linux") allHosts
        );
        inherit specialArgs;
      };
    }
    // lib.mapAttrs (id: host: {
      deployment = deploymentFor host config.flake.nixosConfigurations.${id}.config.scottylabs.bastion;
      imports = modulesFor id host;
    }) nixosHosts
    // lib.mapAttrs (id: host: {
      deployment =
        deploymentFor host config.flake.darwinConfigurations.${id}.config.scottylabs.bastion
        // {
          systemType = "darwin";
          # x86_64 deployers cannot cross-build darwin, and the mini can build itself
          buildOnTarget = true;
        };
      imports = darwinModulesFor id host;
    }) darwinHosts
  );
}
