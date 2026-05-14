{
  config,
  lib,
  hostname,
  ...
}:

let
  cfg = config.scottylabs.promtail;
in
{
  options.scottylabs.promtail = {
    enable = lib.mkEnableOption "Promtail journald log shipper";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9080;
    };

    lokiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://infra-01:3100/loki/api/v1/push";
    };
  };

  config = lib.mkIf cfg.enable {
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.port;
          grpc_listen_port = 0;
        };
        positions.filename = "/var/lib/promtail/positions.yaml";
        clients = [{ url = cfg.lokiUrl; }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = hostname;
            };
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
            {
              source_labels = [ "__journal_priority_keyword" ];
              target_label = "level";
            }
            {
              source_labels = [ "__journal__hostname" ];
              target_label = "hostname";
            }
          ];
        }];
      };
    };
  };
}
