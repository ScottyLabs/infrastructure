{
  description = "ScottyLabs Infrastructure";

  inputs = {
    nixpkgs.url = "github:ap-1/nixpkgs/keycloak-plugins";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
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

    # prod-01
    dalmatian = {
      url = "github:ScottyLabs/dalmatian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    discord-verify = {
      url = "github:ScottyLabs/discord-verify";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    agenix,
    disko,
    comin,
    neovim-nightly-overlay,
    dalmatian,
    discord-verify,
    ...
  }:
  let
    users = import ./users.nix;

    mkSystem = hostname: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit
          hostname
          users
          comin
          neovim-nightly-overlay
          dalmatian
          discord-verify;
      };
      modules = [
        ./hosts/${hostname}/configuration.nix
        ./common

        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        disko.nixosModules.disko
      ];
    };

    hosts = [ "infra-01" "prod-01" "prod-02" ];
  in {
    nixosConfigurations = builtins.listToAttrs (map (hostname: {
      name = hostname;
      value = mkSystem hostname;
    }) hosts);
  };
}
