{ terrier, ... }:

let
  samlProxy = terrier.packages.x86_64-linux.samlProxy;
in
{
  scottylabs.bao-agent = {
    enable = true;
    secrets.saml-proxy = {
      project = "terrier";
      user = "saml-proxy";
    };
    secretFiles.saml-proxy-idp-cert = {
      project = "terrier";
      path = "saml-proxy-certs";
      key = "idp-cert";
      user = "saml-proxy";
    };
    secretFiles.saml-proxy-idp-key = {
      project = "terrier";
      path = "saml-proxy-certs";
      key = "idp-key";
      user = "saml-proxy";
    };
  };

  users.users.saml-proxy = {
    isSystemUser = true;
    group = "saml-proxy";
  };
  users.groups.saml-proxy = { };

  systemd.services.saml-proxy = {
    description = "SAML Proxy for University Authentication";
    after = [ "network-online.target" "bao-agent.service" ];
    wants = [ "network-online.target" "bao-agent.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${samlProxy}/bin/saml-proxy";
      Restart = "always";
      RestartSec = "10s";
      User = "saml-proxy";
      Group = "saml-proxy";
      EnvironmentFile = "/run/secrets/saml-proxy.env";

      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  services.nginx = {
    enable = true;

    virtualHosts."auth.terrier.build" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8443";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
