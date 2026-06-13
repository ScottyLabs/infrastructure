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
    # No handle blocks — NixOS runs caddy fmt on the generated Caddyfile and
    # multi-handle site config fails to parse.
    @markdown header Accept *text/markdown*

    @markdownHtml {
      header Accept *text/markdown*
      path_regexp html ^(?P<stem>.+)\.html$
    }
    rewrite @markdownHtml /{re.html.stem}.md

    @markdownIndex {
      header Accept *text/markdown*
      path_regexp /$
      not path_regexp \.md$
    }
    rewrite @markdownIndex {path}index.md

    @markdownNoSlash {
      header Accept *text/markdown*
      not path_regexp \.md$
      not path_regexp \.html$
      not path_regexp /$
    }
    rewrite @markdownNoSlash {path}/index.md

    header @markdown >Content-Type "text/markdown; charset=utf-8"
    header Vary "Accept"

    reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
      header_up Host scottylabs-docs
    }
  '';
}
