{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:

let
  cfg = config.scottylabs.bao-agent;

  mkProjectTemplate =
    name: secret:
    pkgs.writeText "${name}.env.tpl" ''
      {{- with secret "secret/data/projects/${secret.project}/prod/env" -}}
      {{- range $key, $value := .Data.data }}
      {{ $key | toUpper }}={{ $value }}
      {{- end }}
      {{- end -}}
    '';

  mkInfraTemplate =
    name: secret:
    pkgs.writeText "${name}.tpl" ''
      {{- with secret "secret/data/infra/${secret.path}" -}}
      {{ .Data.data.${secret.key} }}
      {{- end -}}
    '';

  allProjects = lib.unique (lib.mapAttrsToList (_: s: s.project) cfg.secrets);

  agentConfig = pkgs.writeText "bao-agent.hcl" ''
    vault {
      address = "https://secrets2.scottylabs.org"
    }

    auto_auth {
      method "approle" {
        config = {
          role_id_file_path   = "/run/agenix/bao-role-id"
          secret_id_file_path = "/run/agenix/bao-secret-id"
          remove_secret_id_file_after_reading = false
        }
      }

      sink "file" {
        config = {
          path = "/run/bao-agent/token"
          mode = 0440
        }
      }
    }

    template_config {
      static_secret_render_interval = "5m"
    }

    ${lib.concatStrings (
      lib.mapAttrsToList (name: secret: ''
        template {
          source      = "${mkProjectTemplate name secret}"
          destination = "/run/secrets/${name}.env"
          perms       = "0440"
          user        = "${secret.user}"
        }
      '') cfg.secrets
    )}

    ${lib.concatStrings (
      lib.mapAttrsToList (name: secret: ''
        template {
          source      = "${mkInfraTemplate name secret}"
          destination = "/run/secrets/${name}"
          perms       = "0400"
          user        = "${secret.user}"
        }
      '') cfg.infraSecrets
    )}
  '';
in
{
  options.scottylabs.bao-agent = {
    enable = lib.mkEnableOption "OpenBao agent for fetching secrets";

    secrets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            project = lib.mkOption {
              type = lib.types.str;
              description = "Project name in OpenBao path";
            };
            user = lib.mkOption {
              type = lib.types.str;
              description = "User that owns the rendered secret file";
            };
          };
        }
      );
      default = { };
      description = "Secrets to fetch from OpenBao";
    };

    infraSecrets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Path under secret/data/infra/";
            };
            key = lib.mkOption {
              type = lib.types.str;
              description = "Key name within the secret";
            };
            user = lib.mkOption {
              type = lib.types.str;
              description = "User that owns the rendered secret file";
            };
          };
        }
      );
      default = { };
    };

    projects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = allProjects;
      readOnly = true;
      internal = true;
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.bao-role-id = {
      file = ../secrets/${hostname}/bao-role-id.age;
      mode = "0400";
    };

    age.secrets.bao-secret-id = {
      file = ../secrets/${hostname}/bao-secret-id.age;
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d /run/secrets 0755 root root -"
    ];

    systemd.services.bao-agent = {
      description = "OpenBao Agent";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = "/var/lib/bao-agent";
      };

      serviceConfig = {
        ExecStart = "${pkgs.openbao}/bin/bao agent -config=${agentConfig}";
        Restart = "always";
        RestartSec = "5s";
        RuntimeDirectory = "bao-agent";
      };
    };
  };
}
