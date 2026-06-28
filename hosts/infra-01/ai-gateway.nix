{
  config,
  llm-pkgs,
  ...
}:

{
  imports = [
    llm-pkgs.nixosModules.cliproxyapi
  ];

  age.secrets.cli-proxy-api.file = ../../secrets/infra-01/cli-proxy-api.age;

  services.cliproxyapi = {
    enable = true;
    settings = {
      host = "127.0.0.1";
      port = 8317;
      api-keys = [ { _secret = "/run/secrets/cli-proxy-api-key-server"; } ];
      remote-management = {
        allow-remote = false;
        disable-control-panel = true;
        secret-key._secret = config.age.secrets.cli-proxy-api.path;
      };
    };
  };

  systemd.services.cliproxyapi = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
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
        user = "cliproxyapi";
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
