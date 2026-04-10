{ config, pkgs, ... }:

{
  scottylabs.atlantis = {
    enable = true;
    domain = "atlantis.scottylabs.org";
    environmentFile = config.age.secrets.atlantis.path;
    extraPackages = [
      pkgs.opentofu
      pkgs.rustc
      pkgs.cargo
    ];
    extraArgs = [
      "--gitea-base-url=https://codeberg.org"
      "--gitea-user=scottylabs-bot"
      "--repo-allowlist=codeberg.org/ScottyLabs/governance"
    ];
  };

  age.secrets.atlantis = {
    file = ../../secrets/infra-01/atlantis.age;
    owner = "atlantis";
    mode = "0400";
  };
}
