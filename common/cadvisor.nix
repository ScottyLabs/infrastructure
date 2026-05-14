{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.cadvisor;
in
{
  options.scottylabs.cadvisor = {
    enable = lib.mkEnableOption "cAdvisor per-cgroup resource exporter";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4194;
      description = "Port to listen on. Reachable over the tailscale interface only via the existing trustedInterfaces firewall rule.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.cadvisor = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = cfg.port;
    };
  };
}
