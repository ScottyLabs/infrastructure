{
  flake.modules.nixos.snoopy-runner =
    {
      config,
      inputs,
      pkgs,
      ...
    }:

    {
      imports = [
        "${inputs.nixpkgs-forgejo-runner}/nixos/modules/services/continuous-integration/forgejo-runner.nix"
      ];

      age.secrets.forgejo-runner-token = {
        file = ../../../secrets/snoopy/forgejo-runner-token.age;
        mode = "0400";
        owner = "root";
      };

      nix.settings = {
        extra-substituters = [ "https://scottylabs.cachix.org" ];
        extra-trusted-substituters = [ "https://scottylabs.cachix.org" ];
        extra-trusted-public-keys = [
          "scottylabs.cachix.org-1:hajjEX5SLi/Y7yYloiXTt2IOr3towcTGRhMh1vu6Tjg="
        ];
      };

      services.forgejo-runner.instances.scottylabs = {
        enable = true;
        hostPackages =
          (with pkgs; [
            bash
            coreutils
            gitFull
            gnutar
            gzip
            jq
            nodejs
            openssh
          ])
          ++ [
            config.nix.package
            inputs.kennel.packages.x86_64-linux.devenv
          ];

        settings = {
          runner = {
            capacity = 4;
            labels = [ "native:host" ];
          };
          cache = {
            enabled = true;
            port = 8088;
          };
          server.connections.default = {
            url = "https://git.cmu.dev/";
            uuid = "dc946ee1-89f4-423f-a713-5c50a91fa9ad";
          };
        };

        secrets.server.connections.default.token_url = config.age.secrets.forgejo-runner-token.path;
      };

      systemd.services.forgejo-runner-scottylabs.environment.SSL_CERT_FILE =
        "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
}
