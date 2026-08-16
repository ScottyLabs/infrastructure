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
    systemd-vaultd = {
      url = "github:numtide/systemd-vaultd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # infra-01
    keycloak-theme = {
      url = "git+https://git.cmu.dev/ScottyLabs/keycloak-theme";
      flake = false;
    };
    llm-pkgs = {
      url = "git+https://codeberg.org/anish/llm-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    snot = {
      url = "git+https://tangled.org/isabelroses.com/snot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # TODO: https://github.com/NixOS/nixpkgs/pull/529621
    nixpkgs-forgejo-runner = {
      url = "github:emilylange/nixpkgs?ref=nixos/forgejo-runner";
      flake = false;
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # deploy-01
    kennel = {
      url = "git+https://git.cmu.dev/ScottyLabs/kennel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ricochet = {
      url = "git+https://codeberg.org/anish/ricochet";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # infra-02
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    governance = {
      url = "git+https://git.cmu.dev/ScottyLabs/governance";
      flake = false;
    };

    # Flake infrastructure
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    # nix-community/colmena#319 (nix-darwin support) until it merges upstream
    colmena = {
      url = "github:zw3rk/colmena/a6bdf1e2228b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree ./modules)
        inputs.terranix.flakeModule
      ];

      systems = [ "x86_64-linux" ];
    };
}
