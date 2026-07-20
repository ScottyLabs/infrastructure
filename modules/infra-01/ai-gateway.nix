{
  flake.modules.nixos.infra-01-ai-gateway =
    {
      config,
      inputs,
      ...
    }:

    {
      imports = [
        inputs.llm-pkgs.nixosModules.cliproxyapi
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
        models =
          let
            passthrough = id: {
              name = id;
              upstream = "openai/${id}";
            };
          in
          map passthrough [
            "claude-opus-4-8"
            "claude-opus-4-7"
            "claude-opus-4-6"
            "claude-opus-4-5-20251101"
            "claude-opus-4-1-20250805"
            "claude-fable-5"
            "claude-sonnet-5"
            "claude-sonnet-4-6"
            "claude-sonnet-4-5-20250929"
            "claude-haiku-4-5-20251001"
            "gpt-5.6-sol"
            "gpt-5.6-terra"
            "gpt-5.6-luna"
            "gpt-5.5"
            "gpt-5.4"
            "gpt-5.4-mini"
            "codex-auto-review"
          ];
      };
    };
}
