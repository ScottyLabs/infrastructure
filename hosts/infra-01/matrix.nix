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
    # Delegation: tells other homeservers where to find this one
    "m.server" = "${matrixDomain}:443";
  };
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin "*";
    return 200 '${builtins.toJSON data}';
  '';
in
{
  services.matrix-synapse = {
    enable = true;
    settings = {
      server_name = domain;
      public_baseurl = "https://${matrixDomain}";

      # HTTP listener for clients and federation are on 8008
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

      # Database for storing user data, media, etc.
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
      # Disallow users from registering themselves on doggylabs.org
      # This still allows users to register themselves on other trusted servers
      enable_registration = false;
      # This will be used in the future when we want to set up Prometheus metrics
      enable_metrics = false;
      # This is used to verify shared secrets for registration
      registration_shared_secret_path = config.age.secrets.matrix-shared-secret.path;

      trusted_key_servers = [
        {
          server_name = "matrix.org";
        }
      ];
    };
  };

  age.secrets.matrix-shared-secret = {
    file = ../../secrets/infra-01/matrix-shared-secret.age;
    owner = "matrix-synapse";
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

      # Forwarded headers are set by the nginx reverse proxy.
      # In particular this means we preserve the original client's IP address.
      # remote_addr contains real client IP, so it allows banning based on IP in case we need it
      # scheme is the protocol the client used to connect to us, i.e. http or https. Otherwise the client may see the wrong protocol.
      # We explicitly set Host to the original host, so that the server can use the correct host for redirects.
      extraConfig = ''
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        client_max_body_size 100M;
      '';
      proxyWebsockets = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 8448 ];

  scottylabs.postgresql.databases = [ "matrix-synapse" ];
}
