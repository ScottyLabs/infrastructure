{
  config,
  lib,
  pkgs,
  keycloak-theme,
  ...
}:

{
  age.secrets.keycloak = {
    file = ../../secrets/infra-01/keycloak.age;
    mode = "0400";
  };

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "keycloak-magic-link"
    ];

  # Load admin password from agenix secret
  systemd.services.keycloak.serviceConfig.EnvironmentFile = config.age.secrets.keycloak.path;

  services.keycloak = {
    enable = true;
    database = {
      type = "postgresql";
      createLocally = false;
      host = "/run/postgresql"; # unix socket
      name = "keycloak";
      username = "keycloak";
      useSSL = false;
    };

    settings = {
      hostname = "https://idp.scottylabs.org";
      hostname-strict = true;
      hostname-backchannel-dynamic = true;
      proxy-headers = "xforwarded";
      http-enabled = true;
      http-host = "127.0.0.1";
      http-port = 8080;
      log-level = "org.keycloak.broker:debug,org.keycloak.events:debug,org.keycloak.saml:debug,org.keycloak.federation.ldap:debug";
      features = "scripts";
    };

    themes = {
      terrier = pkgs.runCommand "keycloak-terrier-theme" { } ''
        cp -r ${keycloak-theme}/themes/scottylabs $out
      '';
    };

    plugins = with config.services.keycloak.package.plugins; [
      keycloak-discord
      keycloak-magic-link
      keycloak-remember-me-authenticator

      # needed for Unix socket auth
      junixsocket-common
      junixsocket-native-common
    ];
  };

  services.caddy = {
    enable = true;
    virtualHosts."idp.scottylabs.org".extraConfig = ''
      reverse_proxy 127.0.0.1:8080 {
        header_up X-Forwarded-Port {server_port}
      }
    '';
  };

  scottylabs.postgresql.databases = [ "keycloak" ];
}
