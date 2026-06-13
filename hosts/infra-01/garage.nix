{ config, ... }:

{
  scottylabs.garage = {
    enable = true;
    environmentFile = config.age.secrets.garage.path;
    webadmin = {
      enable = true;
      domain = "garage.scottylabs.org";
    };
  };

  scottylabs.bao-agent = {
    enable = true;
    infraSecrets = {
      garage-webadmin-oidc = {
        path = "garage-webadmin-oidc";
        key = "CLIENT_SECRET";
        user = "caddy";
      };
      garage-webadmin-jwt = {
        path = "garage-webadmin-jwt";
        key = "SECRET";
        user = "caddy";
      };
    };
  };

  age.secrets.garage = {
    file = ../../secrets/infra-01/garage.age;
    mode = "0400";
  };

  age.secrets.tofu-garage = {
    file = ../../secrets/infra-01/tofu-garage.age;
    mode = "0400";
  };

  scottylabs.tofu.configurations.garage = {
    source = ../../tofu/garage;
    environmentFile = config.age.secrets.tofu-garage.path;
    after = [ "garage.service" ];
  };

  # Public anonymous-read entry point for the scottylabs-assets bucket.
  # Garage matches buckets by Host header on its s3_web listener, so caddy
  # rewrites Host to the bucket's globalAlias when proxying.
  services.caddy.virtualHosts."assets.scottylabs.org".extraConfig = ''
    reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
      header_up Host scottylabs-assets
    }
  '';

  # Documentation hub static site (built by Forgejo Actions, uploaded to Garage).
  # Accept: text/markdown negotiation serves pre-built .md files to AI agents.
  # Requires this host config on infra-01 — without it, agents get HTML from Garage.
  services.caddy.virtualHosts."docs.scottylabs.org".extraConfig = ''
    # Accept Markdown: https://acceptmarkdown.com/recipes/caddy
    @markdown header Accept *text/markdown*

    handle @markdown {
      rewrite * {path.regexp_replace /\.html$/, `.md`}

      @needsIndex not path_regexp \.md$
      rewrite @needsIndex * {path.regexp_replace `/+$`, ``}/index.md

      reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
        header_up Host scottylabs-docs
      }
      header >Content-Type "text/markdown; charset=utf-8"
      header Vary "Accept"
    }

    handle {
      header Vary "Accept"
      reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
        header_up Host scottylabs-docs
      }
    }
  '';
}
