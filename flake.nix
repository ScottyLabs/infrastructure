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

    # infra-01
    headplane = {
      url = "github:tale/headplane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # prod-01
    dalmatian = {
      url = "github:ScottyLabs/dalmatian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bus-sign = {
      url = "github:ScottyLabs/bus-sign";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    discord-verify = {
      url = "git+https://codeberg.org/ScottyLabs/discord-verify";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    internet-archive = {
      url = "git+https://codeberg.org/ScottyLabs/internet-archive";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    groupme-mirror = {
      url = "git+https://codeberg.org/ScottyLabs/groupme-mirror";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # prod-02
    terrier = {
      url = "git+https://codeberg.org/ScottyLabs/terrier";
      inputs.nixpkgs.follows = "nixpkgs";
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
      headplane,
      dalmatian,
      bus-sign,
      discord-verify,
      internet-archive,
      groupme-mirror,
      terrier,
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
              nixos-hardware
              headplane
              dalmatian
              bus-sign
              discord-verify
              internet-archive
              groupme-mirror
              terrier
              ;
          };
          modules = [
            ./hosts/${hostname}/configuration.nix
            ./common

            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            disko.nixosModules.disko
          ];
        };

      hosts = {
        infra-01 = "x86_64-linux";
        prod-01 = "x86_64-linux";
        prod-02 = "x86_64-linux";
        snoopy = "x86_64-linux";
        bus-sign-display = "aarch64-linux";
      };
    in
    {
      formatter = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );

      nixosConfigurations = builtins.mapAttrs mkSystem hosts;

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
