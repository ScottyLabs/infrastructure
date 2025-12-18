{ config, lib, pkgs, ... }:

let
  cfg = config.scottylabs.valkey;
in
{
  options.scottylabs.valkey = {
    servers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of Valkey server instances to create";
      example = [ "discord-verify" ];
    };
  };

  config = lib.mkIf (cfg.servers != []) {
    services.redis = {
      package = pkgs.valkey;

      servers = lib.listToAttrs (map (name: {
        inherit name;
        value = {
          enable = true;
        };
      }) cfg.servers);
    };
  };
}
