{
  flake.modules.nixos.alloy =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.scottylabs.alloy;

      configText = pkgs.writeText "scottylabs.alloy.in" ''
        loki.relabel "journal" {
          forward_to = []
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          // kennel-build-<project>-<branch> -> unit=kennel-build, project=<project>
          // Branch kinds gated in kennel's webhook handler
          rule {
            source_labels = ["unit"]
            regex         = "kennel-build-(.+)-(?:main|staging|dev|pr-[0-9]+)\\.service"
            replacement   = "''${1}"
            target_label  = "project"
          }
          rule {
            source_labels = ["unit"]
            regex         = "kennel-build-.+"
            replacement   = "kennel-build"
            target_label  = "unit"
          }
          // Logs Drilldown pivots on service_name
          rule {
            source_labels = ["unit"]
            target_label  = "service_name"
          }
          rule {
            source_labels = ["__journal_priority_keyword"]
            target_label  = "level"
          }
          rule {
            source_labels = ["__journal__hostname"]
            target_label  = "hostname"
          }
        }

        loki.source.journal "default" {
          forward_to    = [loki.write.default.receiver]
          max_age       = "12h"
          relabel_rules = loki.relabel.journal.rules
          labels        = {
            job  = "systemd-journal",
            host = "${config.networking.hostName}",
          }
        }

        loki.write "default" {
          endpoint {
            url = "${cfg.lokiUrl}"
          }
        }
      '';

      alloyConfig =
        pkgs.runCommand "scottylabs.alloy" { nativeBuildInputs = [ config.services.alloy.package ]; }
          ''
            cp ${configText} $out
            alloy validate $out
          '';
    in
    {
      options.scottylabs.alloy = {
        enable = lib.mkEnableOption "Grafana Alloy journald log shipper";

        lokiUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://infra-01:3101/loki/api/v1/push";
        };
      };

      config = lib.mkIf cfg.enable {
        services.alloy = {
          enable = true;
          configPath = alloyConfig;
        };
      };
    };
}
