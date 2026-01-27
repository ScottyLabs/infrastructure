{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.postgresql;
in
{
  options.scottylabs.postgresql = {
    databases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of databases to create";
      example = [
        "keycloak"
        "vaultwarden"
      ];
    };
  };

  config = lib.mkIf (cfg.databases != [ ]) {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;

      ensureDatabases = cfg.databases;

      ensureUsers = map (name: {
        inherit name;
        ensureDBOwnership = true;
      }) cfg.databases;
    };
  };
}
