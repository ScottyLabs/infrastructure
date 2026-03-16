{
  config,
  pkgs,
  lib,
  ...
}:

let
  domain = "doggylabs.org";
  matrixDomain = "matrix.${domain}";
  clientConfig = {
    "m.homeserver".base_url = "https://${matrixDomain}";
    "m.identity_server" = { };
  };
  serverConfig = {
    # Tell other homeservers where to find this one
    "m.server" = "${matrixDomain}:443";
  };
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin "*";
    return 200 '${builtins.toJSON data}';
  '';
in
{
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  services.matrix-synapse = {
    enable = true;
    plugins = [ pkgs.matrix-synapse-plugins.matrix-synapse-shared-secret-auth ];
    extraConfigFiles = [ config.age.secrets.double-puppet.path ];
    settings = {
      server_name = domain;
      public_baseurl = "https://${matrixDomain}";

      # HTTP listener for clients and federation
      listeners = [
        {
          port = 8008;
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [
                "client"
                "federation"
              ];
              compress = true;
            }
          ];
        }
      ];

      database = {
        name = "psycopg2";
        allow_unsafe_locale = true;
        args = {
          host = "/run/postgresql";
          database = "matrix-synapse";
          user = "matrix-synapse";
        };
      };

      max_upload_size = "100M";
      url_preview_enabled = true;
      # Disallow users from registering on doggylabs.org, while
      # allowing them to register on other trusted servers
      enable_registration = false;
      enable_metrics = false;
      registration_shared_secret_path = config.age.secrets.matrix-registration.path;

      trusted_key_servers = [
        {
          server_name = "matrix.org";
        }
      ];
    };
  };

  age.secrets.matrix-registration = {
    file = ../../secrets/infra-01/matrix-registration.age;
    owner = "matrix-synapse";
    mode = "0400";
  };

  age.secrets.double-puppet = {
    file = ../../secrets/infra-01/double-puppet.age;
    owner = "matrix-synapse";
    mode = "0400";
  };

  age.secrets.double-puppet-env = {
    file = ../../secrets/infra-01/double-puppet-env.age;
    owner = "mautrix-discord";
    mode = "0400";
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
    locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
  };

  services.nginx.virtualHosts."${matrixDomain}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8008";
      extraConfig = ''
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        client_max_body_size 100M;
      '';
      proxyWebsockets = true;
    };
  };

  services.mautrix-discord = {
    enable = true;
    environmentFile = config.age.secrets.double-puppet-env.path;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = domain;
      };
      appservice = {
        database = {
          type = "postgres";
          uri = "postgresql:///mautrix-discord?host=/run/postgresql";
        };
        bot = {
          username = "discord";
          displayname = "Discord Bridge";
        };
      };
      bridge = {
        double_puppet_server_map = {
          "${domain}" = "https://${matrixDomain}";
        };
        login_shared_secret_map = {
          "${domain}" = "$DOUBLE_PUPPET_SECRET";
        };
        delete_portal_on_channel_delete = true;
        enable_webhook_avatars = true;
        encryption = {
          allow = true;
          default = true;
        };
        relay = {
          enabled = true;
          admin_only = false;
        };
        permissions = {
          "*" = "relay";
          "${domain}" = "user";
          "@ap-1:matrix.org" = "admin";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8448 ];

  scottylabs.postgresql.databases = [
    "matrix-synapse"
    "mautrix-discord"
  ];
}
