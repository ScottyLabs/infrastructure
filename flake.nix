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

    # Flake infrastructure
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree ./modules)
      ];

      systems = [ "x86_64-linux" ];
    };
}
