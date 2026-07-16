{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.postgresql;
  pgExtensions = [
    { pkg = ps: ps.pg_uuidv7; sql = "pg_uuidv7"; }
    { pkg = ps: ps.pgvector;  sql = "vector"; }
    { pkg = ps: ps.postgis;   sql = "postgis"; }
  ];
  createExtSql = lib.concatMapStringsSep " "
    (e: "CREATE EXTENSION IF NOT EXISTS ${e.sql};")
    pgExtensions;
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
      extensions = ps: map (e: e.pkg ps) pgExtensions;

      ensureDatabases = cfg.databases;

      ensureUsers = map (name: {
        inherit name;
        ensureDBOwnership = true;
      }) cfg.databases;
    };

    # Kennel creates service databases at runtime via createdb, which clones template1, so seed it there.
    systemd.services.postgresql-setup.postStart = lib.mkAfter (
      lib.concatMapStringsSep "\n" (db: ''
        psql --port=${toString config.services.postgresql.settings.port} -d ${db} -c '${createExtSql}'
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
      extraFlags = [ "--no-collector.replication" ];
    };
  };
}
