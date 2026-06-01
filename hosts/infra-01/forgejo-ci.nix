{ config, ... }:

{
  age.secrets.codeberg-token = {
    file = ../../secrets/infra-01/codeberg-token.age;
    mode = "0400";
    owner = "webhook";
  };

  age.secrets.forgejo-runner-token = {
    file = ../../secrets/infra-01/forgejo-runner-token.age;
    mode = "0400";
    owner = "gitea-runner";
  };

  scottylabs.forgejoCI = {
    webhook = {
      enable = true;
      tokenFile = config.age.secrets.codeberg-token.path;
    };
    runner = {
      enable = true;
      name = "infra-01";
      tokenFile = config.age.secrets.forgejo-runner-token.path;
      capacity = 4;
    };
  };
}
