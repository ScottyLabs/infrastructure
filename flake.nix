{
  description = "ScottyLabs Infrastructure";

  nixConfig = {
    extra-substituters = [ "https://scottylabs.cachix.org" ];
    extra-trusted-public-keys = [
      "scottylabs.cachix.org-1:hajjEX5SLi/Y7yYloiXTt2IOr3towcTGRhMh1vu6Tjg="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ncro = {
      url = "github:feel-co/ncro";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    srvos.url = "github:nix-community/srvos";

    # infra-01
    keycloak-theme = {
      url = "git+https://codeberg.org/ScottyLabs/keycloak-theme";
      flake = false;
    };
    nixpkgs-keycloak.url = "github:ap-1/nixpkgs/keycloak-plugin-updates";
    llm-pkgs = {
      url = "git+https://codeberg.org/anish/llm-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # deploy-01
    kennel = {
      url = "git+https://codeberg.org/ScottyLabs/kennel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    observability.url = "git+https://codeberg.org/ScottyLabs/observability";
    ricochet = {
      url = "git+https://codeberg.org/anish/ricochet";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    governance = {
      url = "git+https://codeberg.org/ScottyLabs/governance";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      home-manager,
      agenix,
      disko,
      ncro,
      srvos,
      keycloak-theme,
      nixpkgs-keycloak,
      llm-pkgs,
      kennel,
      observability,
      ricochet,
      governance,
      ...
    }:
    let
      users = import ./users.nix;

      specialArgsFor = hostname: {
        inherit
          self
          hostname
          users
          ncro
          srvos
          nixos-hardware
          keycloak-theme
          llm-pkgs
          kennel
          observability
          ricochet
          governance
          ;
      };

      modulesFor = hostname: [
        ./hosts/${hostname}/configuration.nix
        ./common
        ./services

        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        disko.nixosModules.disko

        srvos.nixosModules.server
        srvos.nixosModules.mixins-terminfo
        srvos.nixosModules.mixins-trusted-nix-caches
        { srvos.flake = self; }
        {
          nixpkgs.overlays = [
            (
              _: prev:
              let
                keycloakPkgs = import nixpkgs-keycloak {
                  inherit (prev.stdenv.hostPlatform) system;
                  inherit (prev) config;
                };
              in
              {
                inherit (keycloakPkgs) keycloak;
              }
            )
          ];
        }
      ];

      mkSystem =
        hostname: system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgsFor hostname;
          modules = modulesFor hostname;
        };

      hosts = {
        infra-01 = "x86_64-linux";
        deploy-01 = "x86_64-linux";
        signage-01 = "x86_64-linux";
        snoopy = "x86_64-linux";
      };

      nixosConfigurations = builtins.mapAttrs mkSystem hosts;
    in
    {
      inherit nixosConfigurations;

      colmena = {
        meta = {
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          nodeSpecialArgs = builtins.mapAttrs (hostname: _: specialArgsFor hostname) hosts;
        };
      }
      // builtins.mapAttrs (hostname: _: {
        deployment = {
          targetHost = "${hostname}.scottylabs.org";
          targetUser = "deploy";
        };
        imports = modulesFor hostname;
      }) hosts;
    };
}
