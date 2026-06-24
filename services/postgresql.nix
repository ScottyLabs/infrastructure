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
      package = pkgs.postgresql_18;
      extensions = ps: [ ps.pg_uuidv7 ];

      ensureDatabases = cfg.databases;

      ensureUsers = map (name: {
        inherit name;
        ensureDBOwnership = true;
      }) cfg.databases;
    };

    # Kennel creates service databases at runtime via createdb, which clones template1, so seed it there.
    systemd.services.postgresql-setup.postStart = lib.mkAfter (
      lib.concatMapStringsSep "\n" (db: ''
        psql --port=${toString config.services.postgresql.settings.port} -d ${db} -c 'CREATE EXTENSION IF NOT EXISTS pg_uuidv7;'
      '') ([ "template1" ] ++ cfg.databases)
    );

    services.pgadmin = {
      enable = true;
      initialEmail = "admin@scottylabs.org";
      initialPasswordFile = config.age.secrets.pgadmin.path;
    };

    age.secrets.pgadmin = {
      file = ../secrets/pgadmin.age;
      owner = "pgadmin";
      mode = "0400";
    };

    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 5050 ]; # pgadmin

    services.prometheus.exporters.postgres = {
      enable = true;
      runAsLocalSuperUser = true;
    };
  };
}
