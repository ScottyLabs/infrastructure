{ ncro, lib, ... }:

{
  imports = [ ncro.nixosModules.ncro ];

  services.ncro = {
    enable = true;
    settings = {
      server.listen = "127.0.0.1:5000";

      upstreams = [
        {
          url = "https://cache.nixos.org";
          priority = 10;
          public_key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        }
        {
          url = "https://scottylabs.cachix.org";
          priority = 20;
          public_key = "scottylabs.cachix.org-1:hajjEX5SLi/Y7yYloiXTt2IOr3towcTGRhMh1vu6Tjg=";
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
  nix.settings.substituters = lib.mkForce [ "http://localhost:5000" ];
}
