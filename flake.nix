{
  description = "ScottyLabs Infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
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

