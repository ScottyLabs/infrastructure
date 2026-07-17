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
    comin = {
      url = "github:nlewo/comin";
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
      comin,
      ncro,
      srvos,
      keycloak-theme,
      llm-pkgs,
      kennel,
      observability,
      ricochet,
      governance,
      ...
    }:
    let
      users = import ./users.nix;

      mkSystem =
        hostname: system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              self
              hostname
              users
              comin
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
          modules = [
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
          ];
        };

      hosts = {
        infra-01 = "x86_64-linux";
        deploy-01 = "x86_64-linux";
        snoopy = "x86_64-linux";
        bus-sign-display = "x86_64-linux";
      };

      nixosConfigurations = builtins.mapAttrs mkSystem hosts;

    in
    {
      formatter = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );

      inherit nixosConfigurations;

      # Host-to-project mapping for OpenBao AppRole policies
      packages.x86_64-linux.host-projects =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          mapping = builtins.mapAttrs (
            hostname: _: self.nixosConfigurations.${hostname}.config.scottylabs.bao-agent.projects
          ) hosts;
        in
        pkgs.writeText "host-projects.json" (builtins.toJSON mapping);
    };
}
