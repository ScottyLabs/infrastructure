{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.matrix;
in
{
  options.scottylabs.matrix.synapse = {
    registrationSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file containing the registration shared secret.";
    };

    extraConfigFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to an extra YAML config file merged into synapse (e.g. double-puppet bridge secret).";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8008;
      description = "HTTP listener port for clients and federation.";
    };

    maxUploadSize = lib.mkOption {
      type = lib.types.str;
      default = "100M";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.permittedInsecurePackages = [
      "olm-3.2.16"
    ];

    services.matrix-synapse = {
      enable = true;
      plugins = [ pkgs.matrix-synapse-plugins.matrix-synapse-shared-secret-auth ];
      extraConfigFiles = [ cfg.synapse.extraConfigFile ];
      settings = {
        server_name = cfg.domain;
        public_baseurl = "https://${cfg.matrixDomain}";

        rc_joins = {
          local = {
            per_second = 50;
            burst_count = 200;
          };
          remote = {
            per_second = 10;
            burst_count = 50;
          };
        };

        listeners = [
          {
            port = cfg.synapse.listenPort;
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

        max_upload_size = cfg.synapse.maxUploadSize;
        url_preview_enabled = true;
        # Disallow users from registering on this homeserver, while
        # allowing them to register on other trusted servers
        enable_registration = false;
        enable_metrics = false;
        registration_shared_secret_path = cfg.synapse.registrationSecretFile;

        trusted_key_servers = [
          {
            server_name = "matrix.org";
          }
        ];
      };
    };

    services.caddy.virtualHosts.${cfg.matrixDomain}.extraConfig = ''
      request_body {
        max_size 100MB
      }
      reverse_proxy 127.0.0.1:${toString cfg.synapse.listenPort}
    '';

    networking.firewall.allowedTCPPorts = [ 8448 ];

    scottylabs.postgresql.databases = [ "matrix-synapse" ];
  };
}
