{
  description = "ScottyLabs Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
      url = "github:ScottyLabs/terrier/judging";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      disko,
      comin,
      headplane,
      dalmatian,
      discord-verify,
      internet-archive,
      groupme-mirror,
      terrier,
      ...
    }:
    let
      users = import ./users.nix;

      mkSystem =
        hostname:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit
              self
              hostname
              users
              comin
              headplane
              dalmatian
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

      hosts = [
        "infra-01"
        "prod-01"
        "prod-02"
        "snoopy"
      ];
    in
    {
      formatter = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );

      nixosConfigurations = builtins.listToAttrs (
        map (hostname: {
          name = hostname;
          value = mkSystem hostname;
        }) hosts
      );

      # Host-to-project mapping for OpenBao AppRole policies
      packages.x86_64-linux.host-projects =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          mapping = builtins.listToAttrs (
            map (hostname: {
              name = hostname;
              value = self.nixosConfigurations.${hostname}.config.scottylabs.bao-agent.projects;
            }) hosts
          );
        in
        pkgs.writeText "host-projects.json" (builtins.toJSON mapping);
    };
}
