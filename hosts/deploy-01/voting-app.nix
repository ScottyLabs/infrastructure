{ voting-app, ... }:

let
  votingAppBackend = voting-app.packages.x86_64-linux.votingAppBackend;
  votingAppFrontend = voting-app.packages.x86_64-linux.votingAppFrontend;
in
{
  scottylabs.bao-agent = {
    enable = true;
    secrets.voting-app = {
      project = "voting-app";
      user = "voting-app";
    };
  };

  users.users.voting-app = {
    isSystemUser = true;
    group = "voting-app";
  };
  users.groups.voting-app = { };

  systemd.services.voting-app = {
    description = "Senate Voting Application Backend";
    after = [
      "network-online.target"
      "postgresql.service"
      "bao-agent.service"
    ];
    wants = [
      "network-online.target"
      "bao-agent.service"
    ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${votingAppBackend}/bin/backend";
      Restart = "always";
      RestartSec = "10s";
      User = "voting-app";
      Group = "voting-app";
      EnvironmentFile = "/run/secrets/voting-app.env";

      # Sandboxing
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };

    environment = {
      API_HOST = "127.0.0.1";
      API_PORT = "8081";
      DATABASE_URL = "postgresql:///voting-app?host=/run/postgresql";
    };
  };

  scottylabs.postgresql.databases = [ "voting-app" ];

  services.caddy.virtualHosts."voting.scottylabs.org".extraConfig = ''
    root * ${votingAppFrontend}
    handle /api/* {
      reverse_proxy 127.0.0.1:8081
    }
    handle {
      try_files {path} {path}/ /index.html
      file_server
    }
  '';
}
