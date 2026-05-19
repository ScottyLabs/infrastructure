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
  };
}
