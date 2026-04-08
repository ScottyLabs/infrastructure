{ cmugpt-agent, lib, ... }:

let
  cmugptAgentPkg = cmugpt-agent.packages.x86_64-linux.default;
in
{
  scottylabs.bao-agent = {
    enable = true;
    secrets.cmugpt-agent = {
      project = "cmugpt-agent";
      user = "cmugpt-agent";
    };
  };

  users.users.cmugpt-agent = {
    isSystemUser = true;
    group = "cmugpt-agent";
  };
  users.groups.cmugpt-agent = { };

  systemd.services.cmugpt-agent = {
    description = "CMUGPT agent (Flask API for campus RAG / LLM)";
    after = [
      "network-online.target"
      "bao-agent.service"
    ];
    wants = [
      "network-online.target"
      "bao-agent.service"
    ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      CMUGPT_HOST = "127.0.0.1";
      CMUGPT_PORT = "8000";
      CMUGPT_DEBUG = "false";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = lib.getExe cmugptAgentPkg;
      Restart = "on-failure";
      RestartSec = "10s";
      User = "cmugpt-agent";
      Group = "cmugpt-agent";
      EnvironmentFile = "/run/secrets/cmugpt-agent.env";

      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  services.nginx = {
    enable = true;

    virtualHosts."cmugpt-agent.scottylabs.org" = {
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 25m;
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
        '';
      };
    };
  };
}
