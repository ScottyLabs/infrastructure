{
  config,
  lib,
  pkgs,
  headplane,
  ...
}:

let
  format = pkgs.formats.yaml { };
  headscaleConfigForHeadplane = format.generate "headscale.yml" (
    lib.recursiveUpdate config.services.headscale.settings {
      tls_cert_path = "";
      tls_key_path = "";
    }
  );

  aclPolicy = builtins.toJSON {
    acls = [
      {
        action = "accept";
        src = [ "*" ];
        dst = [ "*:*" ];
      }
    ];

    ssh = [
      {
        action = "accept";
        src = [ "autogroup:member" ];
        dst = [ "group:servers" ];
        users = [
          "autogroup:nonroot"
          "root"
        ];
      }
    ];

    autoApprovers = {
      exitNode = [ "group:servers" ];
    };
  };
in
{
  imports = [
    headplane.nixosModules.headplane
  ];

  scottylabs.bao-agent = {
    enable = true;
    infraSecrets = {
      headscale-oidc = {
        path = "headscale-oidc";
        key = "CLIENT_SECRET";
        user = "headscale";
      };
      headplane-oidc = {
        path = "headplane-oidc";
        key = "CLIENT_SECRET";
        user = "headscale";
      };
      headplane-cookie = {
        path = "headplane-cookie";
        key = "SECRET";
        user = "headscale";
      };
      headplane-agent-key = {
        path = "headplane-agent-key";
        key = "PREAUTH_KEY";
        user = "headscale";
      };
      headplane-api-key = {
        path = "headplane-api-key";
        key = "API_KEY";
        user = "headscale";
      };
    };
  };

  # Write ACL policy file
  environment.etc."headscale/acl.json" = {
    text = aclPolicy;
    user = "headscale";
    group = "headscale";
    mode = "0400";
  };

  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 8085;

    settings = {
      server_url = "https://headscale.scottylabs.org";

      prefixes = {
        v4 = "100.64.0.0/10";
        v6 = "fd7a:115c:a1e0::/48";
      };

      derp = {
        urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
        auto_update_enabled = true;
        update_frequency = "24h";
      };

      dns = {
        magic_dns = true;
        base_domain = "tail.scottylabs.org";
        nameservers.global = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };

      oidc = {
        issuer = "https://idp.scottylabs.org/realms/scottylabs";
        client_id = "headscale";
        client_secret_path = "/run/secrets/headscale-oidc";
        scope = [
          "openid"
          "profile"
          "email"
        ];
        allowed_groups = [ "/projects/devops" ];
      };

      log.level = "info";

      database = {
        type = "postgres";
        postgres = {
          host = "/run/postgresql";
          port = 5432;
          name = "headscale";
          user = "headscale";
        };
      };

      policy = {
        mode = "file";
        path = "/etc/headscale/acl.json";
      };
    };
  };

  systemd.services.headscale = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };

  nixpkgs.overlays = [ headplane.overlays.default ];

  services.headplane = {
    enable = true;
    settings = {
      server = {
        host = "127.0.0.1";
        port = 3100;
        cookie_secret_path = "/run/secrets/headplane-cookie";
      };

      headscale = {
        url = "https://headscale.scottylabs.org";
        config_path = "${headscaleConfigForHeadplane}";
        config_strict = false;
      };

      oidc = {
        issuer = "https://idp.scottylabs.org/realms/scottylabs";
        client_id = "headplane";
        client_secret_path = "/run/secrets/headplane-oidc";
        redirect_uri = "https://headplane.scottylabs.org/admin/oidc/callback";
        headscale_api_key_path = "/run/secrets/headplane-api-key";
        disable_api_key_login = false;
      };

      integration = {
        proc.enabled = true;
        agent = {
          enabled = true;
          pre_authkey_path = "/run/secrets/headplane-agent-key";
        };
      };
    };
  };

  systemd.services.headplane = {
    after = [
      "bao-agent.service"
      "headscale.service"
    ];
    wants = [
      "bao-agent.service"
      "headscale.service"
    ];
  };

  services.nginx.virtualHosts = {
    "headscale.scottylabs.org" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.headscale.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_buffering off;
        '';
      };
    };

    "headplane.scottylabs.org" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3100";
        proxyWebsockets = true;
      };
    };
  };

  scottylabs.postgresql.databases = [ "headscale" ];
}
