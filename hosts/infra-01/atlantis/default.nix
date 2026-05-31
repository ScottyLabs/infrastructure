{ config, pkgs, ... }:

{
  scottylabs.atlantis = {
    enable = true;
    domain = "atlantis.scottylabs.org";
    environmentFile = config.age.secrets.atlantis.path;
    extraPackages = [
      pkgs.opentofu
      pkgs.go
      pkgs.unzip
      pkgs.curl
      pkgs.cargo
      pkgs.rustc
      pkgs.gcc
    ];
    extraArgs = [
      "--gitea-base-url=https://codeberg.org"
      "--gitea-user=scottylabs-bot"
      "--repo-allowlist=codeberg.org/ScottyLabs/governance"
      "--allow-fork-prs"
      "--default-tf-distribution=opentofu"
      "--write-git-creds"
      "--allow-commands=version,plan,apply,unlock,approve_policies,cancel,import,state"
      "--silence-vcs-status-no-plans"
      "--hide-prev-plan-comments"
      "--enable-diff-markdown-format"
      "--repo-config=${./repo-config.yml}"
    ];
  };

  age.secrets.atlantis = {
    file = ../../../secrets/infra-01/atlantis.age;
    owner = "atlantis";
    mode = "0400";
  };
}
