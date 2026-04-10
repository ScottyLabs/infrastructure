{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.atlantis;
in
{
  options.scottylabs.atlantis = {
    enable = lib.mkEnableOption "Atlantis Terraform/OpenTofu PR automation";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.atlantis;
      description = "Atlantis package to use";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to environment file containing secrets";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4141;
      description = "Port for the Atlantis web server";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain name for the Atlantis web UI";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional command-line arguments for atlantis server";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to make available in Atlantis PATH";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.atlantis = {
      description = "Atlantis Terraform/OpenTofu PR Automation";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      path = [
        pkgs.git
      ] ++ cfg.extraPackages;

      serviceConfig = {
        Type = "simple";
        User = "atlantis";
        Group = "atlantis";
        EnvironmentFile = cfg.environmentFile;
        ExecStart = lib.concatStringsSep " " ([
          "${cfg.package}/bin/atlantis server"
          "--atlantis-url=https://${cfg.domain}"
          "--port=${toString cfg.port}"
          "--data-dir=/var/lib/atlantis"
        ] ++ cfg.extraArgs);
        StateDirectory = "atlantis";
        Restart = "always";
        RestartSec = 5;
      };
    };

    users.users.atlantis = {
      isSystemUser = true;
      group = "atlantis";
      home = "/var/lib/atlantis";
    };
    users.groups.atlantis = { };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
