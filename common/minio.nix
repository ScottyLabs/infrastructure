{ config, lib, pkgs, ... }:

let
  cfg = config.scottylabs.minio;
  instanceList = lib.attrNames cfg.instances;
in
{
  options.scottylabs.minio = {
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            description = "Port for MinIO API server";
          };
          consolePort = lib.mkOption {
            type = lib.types.port;
            description = "Port for MinIO console UI";
          };
          credentialsFile = lib.mkOption {
            type = lib.types.path;
            description = ''
              Path to file containing MINIO_ROOT_USER and MINIO_ROOT_PASSWORD.

              The file must be group-readable (mode 0440) with group set to
              the instance name for the minio-<name> user to access it.
            '';
          };
        };
      });
      default = {};
      description = ''
        MinIO server instances to create.

        Each instance runs as minio-<name> and gets its own data directory
        at /var/lib/minio-<name>, plus an nginx virtualHost at s3.<name>.scottylabs.org.

        The system user <name> is added to the minio-<name> group for data access.
        The minio-<name> user is added to the <name> group for credential access.
      '';
      example = {
        myapp = {
          port = 9000;
          consolePort = 9001;
          credentialsFile = config.age.secrets.myapp.path;
        };
      };
    };
  };

  config = lib.mkIf (cfg.instances != {}) {
    # Create a MinIO service for each instance
    systemd.services = lib.mapAttrs' (name: instanceCfg: {
      name = "minio-${name}";
      value = {
        description = "MinIO Object Storage (${name})";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "notify";
          User = "minio-${name}";
          Group = "minio-${name}";
          EnvironmentFile = instanceCfg.credentialsFile;
          ExecStart = "${pkgs.minio}/bin/minio server --address :${toString instanceCfg.port} --console-address :${toString instanceCfg.consolePort} /var/lib/minio-${name}";
          Restart = "always";
          LimitNOFILE = 65536;
          TimeoutStopSec = "infinity";
          SendSIGKILL = "no";

          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ "/var/lib/minio-${name}" ];
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
        };
      };
    }) cfg.instances;

    # Configure nginx virtualHosts
    services.nginx = {
      enable = true;
      virtualHosts = lib.mapAttrs' (name: instanceCfg: {
        name = "s3.${name}.scottylabs.org";
        value = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://localhost:${toString instanceCfg.port}";
          };
        };
      }) cfg.instances;
    };

    # Create user and group for each instance
    users.users = lib.mkMerge [
      # minio-<name> service user for credential access
      (lib.mapAttrs' (name: _: {
        name = "minio-${name}";
        value = {
          isSystemUser = true;
          group = "minio-${name}";
          extraGroups = [ name ];
        };
      }) cfg.instances)

      # Add application users to minio-<name> group for data access
      (lib.mapAttrs' (name: _: {
        inherit name;
        value = {
          extraGroups = [ "minio-${name}" ];
        };
      }) cfg.instances)
    ];

    users.groups = lib.mapAttrs' (name: _: {
      name = "minio-${name}";
      value = {};
    }) cfg.instances;

    # Create data directories
    systemd.tmpfiles.rules = map (name:
      "d /var/lib/minio-${name} 0750 minio-${name} minio-${name} -"
    ) instanceList;
  };
}
