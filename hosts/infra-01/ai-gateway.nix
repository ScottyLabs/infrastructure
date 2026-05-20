{
  config,
  llm-agents,
  ...
}:

{
  nixpkgs.overlays = [ llm-agents.overlays.default ];

  age.secrets.cli-proxy-api = {
    file = ../../secrets/infra-01/cli-proxy-api.age;
    mode = "0400";
    owner = "cli-proxy-api";
  };

  scottylabs.cli-proxy-api = {
    enable = true;
    environmentFile = config.age.secrets.cli-proxy-api.path;
    apiKeyFiles = [ "/run/secrets/cli-proxy-api-key-server" ];
  };

  scottylabs.bao-agent = {
    enable = true;
    infraSecrets = {
      litellm-master-key = {
        path = "litellm-master-key";
        key = "MASTER_KEY";
        user = "litellm";
      };
      litellm-salt-key = {
        path = "litellm-salt-key";
        key = "SALT_KEY";
        user = "litellm";
      };
      litellm-oidc = {
        path = "litellm-oidc";
        key = "CLIENT_SECRET";
        user = "litellm";
      };
      cli-proxy-api-key-server = {
        path = "cli-proxy-api-key";
        key = "API_KEY";
        user = "cli-proxy-api";
      };
      cli-proxy-api-key-client = {
        path = "cli-proxy-api-key";
        key = "API_KEY";
        user = "litellm";
      };
    };
  };

  scottylabs.ai-gateway.litellm = {
    enable = true;
    masterKeyFile = "/run/secrets/litellm-master-key";
    saltKeyFile = "/run/secrets/litellm-salt-key";
    oidcClientSecretFile = "/run/secrets/litellm-oidc";
    cliProxyApiKeyFile = "/run/secrets/cli-proxy-api-key-client";
  };
}
