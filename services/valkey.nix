{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.valkey;
in
{
  options.scottylabs.valkey = {
    servers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        List of Valkey server instances to create.

        Each server gets a Unix socket at /run/redis-<name>/redis.sock.
        A system user with the same name is automatically added to the
        redis-<name> group for socket access.
      '';
      example = [ "discord-verify" ];
    };
  };

  config = lib.mkIf (cfg.servers != [ ]) {
    services.redis = {
      package = pkgs.valkey;

      servers = lib.listToAttrs (
        map (name: {
          inherit name;
          value = {
            enable = true;
          };
        }) cfg.servers
      );
    };

    users.users = lib.listToAttrs (
      map (name: {
        inherit name;
        value = {
          extraGroups = [ "redis-${name}" ];
        };
      }) cfg.servers
    );
  };
}
