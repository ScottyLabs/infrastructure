{ bus-sign, ... }:

let
  bs = bus-sign.packages.x86_64-linux;
  # bus-sign flake renamed packages: busSign* → backend / frontend
  busSignBackend = if bs ? backend then bs.backend else bs.busSignBackend;
  busSignFrontend = if bs ? frontend then bs.frontend else bs.busSignFrontend;
in
{
  scottylabs.bao-agent = {
    enable = true;
    secrets.bus-sign = {
      project = "bus-sign";
      user = "bus-sign";
    };
  };

  users.users.bus-sign = {
    isSystemUser = true;
    group = "bus-sign";
  };
  users.groups.bus-sign = { };

  systemd.services.bus-sign = {
    description = "CUC Bus Sign Backend";
    after = [
      "network-online.target"
      "bao-agent.service"
    ];
    wants = [
      "network-online.target"
      "bao-agent.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${busSignBackend}/bin/backend";
      Restart = "always";
      RestartSec = "10s";
      User = "bus-sign";
      Group = "bus-sign";
      EnvironmentFile = "/run/secrets/bus-sign.env";

      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };

    environment = {
      API_HOST = "127.0.0.1";
      API_PORT = "8080";
    };
  };

  services.caddy.virtualHosts."bus-sign.scottylabs.org".extraConfig = ''
    root * ${busSignFrontend}
    handle /predictions* {
      reverse_proxy 127.0.0.1:8080
    }
    handle {
      try_files {path} {path}/ /index.html
      file_server
    }
  '';
}
