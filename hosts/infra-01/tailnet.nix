{ ... }:

{
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
      headplane-api-key = {
        path = "headplane-api-key";
        key = "API_KEY";
        user = "headscale";
      };
    };
  };

  scottylabs.tailnet = {
    headscale = {
      enable = true;
      oidcClientSecretFile = "/run/secrets/headscale-oidc";
    };
    headplane = {
      enable = true;
      oidcClientSecretFile = "/run/secrets/headplane-oidc";
      cookieSecretFile = "/run/secrets/headplane-cookie";
      apiKeyFile = "/run/secrets/headplane-api-key";
    };
  };
}
