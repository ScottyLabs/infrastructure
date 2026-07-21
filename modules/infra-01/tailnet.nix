{
  flake.modules.nixos.infra-01-tailnet = {
    scottylabs.tailnet = {
      headscale = {
        enable = true;
        oidcClientSecretFile = "/run/credentials/headscale.service/CLIENT_SECRET";
      };
      headplane = {
        enable = true;
        oidcClientSecretFile = "/run/credentials/headplane.service/oidc";
        cookieSecretFile = "/run/credentials/headplane.service/cookie";
        apiKeyFile = "/run/credentials/headplane.service/apikey";
      };
    };

    systemd.services.headscale.vault.infraSecrets.CLIENT_SECRET = {
      path = "headscale-oidc";
      key = "CLIENT_SECRET";
    };

    systemd.services.headplane.vault.infraSecrets = {
      oidc = {
        path = "headplane-oidc";
        key = "CLIENT_SECRET";
      };
      cookie = {
        path = "headplane-cookie";
        key = "SECRET";
      };
      apikey = {
        path = "headplane-api-key";
        key = "API_KEY";
      };
    };
  };
}
