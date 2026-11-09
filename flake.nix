{
  description = "ScottyLabs Infrastructure";

  nixConfig = {
    extra-substituters = [ "https://scottylabs.cachix.org" ];
    extra-trusted-public-keys = [
      "scottylabs.cachix.org-1:hajjEX5SLi/Y7yYloiXTt2IOr3towcTGRhMh1vu6Tjg="
    ];
  };

  inputs = {
    nixpkgs.follows = "kennel/nixpkgs";
    nixpkgs-hosts.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    ncro = {
      url = "github:feel-co/ncro";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    iets = {
      url = "github:numtide/iets";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    srvos.url = "github:nix-community/srvos";
    systemd-vaultd = {
      url = "github:numtide/systemd-vaultd";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };

    # infra-01
    llm-pkgs = {
      url = "git+https://codeberg.org/anish/llm-pkgs";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    snot = {
      url = "git+https://tangled.org/isabelroses.com/snot";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    nixbot = {
      # TODO: https://github.com/Mic92/nixbot/pull/255
      # TODO: https://github.com/Mic92/nixbot/pull/286
      url = "github:ap-1/nixbot/scottylabs";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };

    # deploy-01
    kennel.url = "git+https://git.cmu.dev/ScottyLabs/kennel";
    ricochet = {
      url = "git+https://codeberg.org/anish/ricochet";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };

    # infra-02
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    governance = {
      url = "git+https://git.cmu.dev/ScottyLabs/governance";
      flake = false;
    };

    # Flake infrastructure
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    # TODO: https://github.com/nix-community/colmena/pull/319
    colmena = {
      url = "github:zw3rk/colmena/a6bdf1e2228b";
      inputs.nixpkgs.follows = "nixpkgs-hosts";
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
