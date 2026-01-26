{ pkgs, ... }:

let
  # Returns the Keycloak issuer URL for scottylabs.org domain
  webfingerResponse = pkgs.writeText "webfinger.json" (builtins.toJSON {
    subject = "acct:admin+tailscale@scottylabs.org";
    links = [{
      rel = "http://openid.net/specs/connect/1.0/issuer";
      href = "https://idp.scottylabs.org/realms/scottylabs";
    }];
  });
in
{
  services.nginx = {
    enable = true;

    virtualHosts."scottylabs.org" = {
      enableACME = true;
      forceSSL = true;

      # Serve WebFinger endpoint for Tailscale OIDC
      locations."= /.well-known/webfinger" = {
        alias = webfingerResponse;
        extraConfig = ''
          default_type application/jrd+json;
          add_header Access-Control-Allow-Origin "*";
        '';
      };

      # Proxy everything else to www.scottylabs.org
      locations."/" = {
        proxyPass = "https://www.scottylabs.org";
        extraConfig = ''
          proxy_set_header Host www.scottylabs.org;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_ssl_server_name on;
        '';
      };
    };
  };
}
