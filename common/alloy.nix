{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:

let
  cfg = config.scottylabs.alloy;

  alloyConfig = pkgs.writeText "scottylabs.alloy" ''
    loki.relabel "journal" {
      forward_to = [loki.write.default.receiver]
      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
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
      forward_to    = [loki.relabel.journal.receiver]
      max_age       = "12h"
      relabel_rules = ""
      labels        = {
        job  = "systemd-journal",
        host = "${hostname}",
      }
    }

    loki.write "default" {
      endpoint {
        url = "${cfg.lokiUrl}"
      }
    }
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
}
