{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.prometheus;
in
{
  options.scottylabs.prometheus = {
    enable = lib.mkEnableOption "Prometheus server";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Bind address. Tailscale interface only is enforced by the host firewall.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
    };

    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "30d";
    };

    scrapeJobs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Scrape jobs contributed by host modules.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      checkConfig = "syntax-only";
      inherit (cfg) listenAddress;
      inherit (cfg) port;
      inherit (cfg) retentionTime;
      scrapeConfigs = cfg.scrapeJobs;
      globalConfig = {
        scrape_interval = "30s";
        evaluation_interval = "30s";
      };
    };
  };
}
