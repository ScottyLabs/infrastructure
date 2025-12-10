{
  description = "ScottyLabs Infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
  };

  outputs = { self, nixpkgs, home-manager, agenix, disko, neovim-nightly-overlay, ... }:
  let
    mkSystem = hostname: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit hostname userWhitelist; };
      modules = [
        ./hosts/${hostname}/configuration.nix
        ./common

        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        disko.nixosModules.disko
      ];
    };

    userWhitelist = {
      apallati = { gitName = "Anish Pallati"; gitEmail = "i@anish.land"; };
      jefferyo = { gitName = "Jeffery Oo";    gitEmail = "jefferyo@andrew.cmu.edu"; };
    };

    hosts = [ "infra-01" "prod-01" "prod-02" ];
  in {
    nixosConfigurations = builtins.listToAttrs (map (hostname: {
      name = hostname;
      value = mkSystem hostname;
    }) hosts);
  };
}
