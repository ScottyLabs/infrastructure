{ inputs, ... }:
let
  ncro =
    { lib, ... }:

    {
      services.ncro = {
        enable = true;
        settings = {
          # macOS's AirPlay Receiver holds 5000
          server.listen = "127.0.0.1:5002";

          upstreams = [
            {
              url = "https://cache.nixos.org";
              priority = 10;
              public_key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
            }
            {
              url = "https://nix-community.cachix.org";
              priority = 30;
              public_key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
            }
            {
              url = "https://numtide.cachix.org";
              priority = 40;
              public_key = "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=";
            }
          ];

          cache = {
            db_path = "/var/lib/ncro/routes.db";
            negative_ttl = "10m";
          };

          logging = {
            level = "info";
            format = "json";
          };
        };
      };

      # Route all substitution on this host through ncro
      nix.settings.substituters = lib.mkForce [ "http://127.0.0.1:5002" ];
      # ncro's negative_ttl already covers misses
      nix.settings.narinfo-cache-negative-ttl = 0;
    };
in
{
  flake.modules.nixos.ncro = {
    imports = [
      inputs.ncro.nixosModules.ncro
      ncro
    ];
  };

  flake.modules.darwin.ncro = {
    imports = [
      inputs.ncro.darwinModules.ncro
      ncro
    ];

    # ncro's default 536 belongs to _harmonia in nix-darwin
    users.users._ncro.uid = 537;
    users.groups._ncro.gid = 537;
  };
}
