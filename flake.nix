{
  description = "ScottyLabs Infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, agenix, ... }: {
    nixosConfigurations.infra-01 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/infra-01/configuration.nix
        ./modules/common.nix
        ./modules/users.nix
        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
      ];
    };
  };
}

