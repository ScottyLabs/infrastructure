{
  flake.modules.nixos.infra-01-garage =
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

      systemd.services.caddy.vault.infraSecrets = {
        oidc = {
          path = "garage-webadmin-oidc";
          key = "CLIENT_SECRET";
        };
        jwt = {
          path = "garage-webadmin-jwt";
          key = "SECRET";
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
        environmentFile = [ config.age.secrets.tofu-garage.path ];
        after = [ "garage.service" ];
      };

      # Public read-only vhost for the scottylabs-assets bucket, Host rewritten to its globalAlias
      services.caddy.virtualHosts."assets.scottylabs.org".extraConfig = ''
        reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
          header_up Host scottylabs-assets
        }
      '';

      # Public read-only CDN for per-project buckets, /<repo>/<key> serves <key> from cdn-<repo>
      services.caddy.virtualHosts."cdn.scottylabs.org".extraConfig = ''
        @cdn path_regexp seg ^/([^/]+)/(.*)$
        rewrite @cdn /{re.seg.2}
        reverse_proxy localhost:${toString config.scottylabs.garage.webPort} {
          header_up Host cdn-{re.seg.1}
        }
      '';

      # Documentation hub static site served from Garage
      # Accept text/markdown negotiation serves pre-built .md files
      services.caddy.virtualHosts."docs.scottylabs.org".extraConfig = ''
        # Accept Markdown: https://acceptmarkdown.com/recipes/caddy
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
    };
}
