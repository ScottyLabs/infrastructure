{
  flake.modules.nixos.infra-01-keycloak =
    {
      config,
      pkgs,
      inputs,
      ...
    }:

    let
      keycloak-minecraft-idp = pkgs.fetchurl {
        url = "https://github.com/groundsgg/keycloak-minecraft-idp/releases/download/v1.1.3/keycloak-minecraft-idp-1.1.3.jar";
        hash = "sha256-tL+snexMXmrNTv6uFvZZbpfDQ+MQsOICAVkvDGHiR7U=";
      };
    in
    {
      nixpkgs.overlays = [
        (_: prev: {
          inherit
            (import inputs.nixpkgs-keycloak {
              inherit (prev.stdenv.hostPlatform) system;
              inherit (prev) config;
            })
            keycloak
            ;
        })
      ];

      age.secrets.keycloak = {
        file = ../../secrets/infra-01/keycloak.age;
        mode = "0400";
      };

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
          metrics-enabled = true;
          health-enabled = true;
          http-management-port = 9092;
        };

        themes = {
          terrier = pkgs.runCommand "keycloak-terrier-theme" { } ''
            cp -r ${inputs.keycloak-theme}/themes/scottylabs $out
          '';
        };

        plugins = with config.services.keycloak.package.plugins; [
          apple-identity-provider-keycloak
          keycloak-discord
          keycloak-remember-me-authenticator
          keycloak-minecraft-idp

          # Unix socket auth
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
    };
}
