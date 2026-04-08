{ bus-sign, ... }:

let
  busSignBackend = bus-sign.packages.x86_64-linux.busSignBackend;
  busSignFrontend = bus-sign.packages.x86_64-linux.busSignFrontend;
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

  services.nginx = {
    enable = true;

    virtualHosts."bus-sign.scottylabs.org" = {
      enableACME = true;
      forceSSL = true;

      root = busSignFrontend;

      locations."/" = {
        tryFiles = "$uri $uri/ /index.html";
      };

      locations."/predictions" = {
        proxyPass = "http://127.0.0.1:8080";
      };
    };
  };
}
