{ config, pkgs, ... }:

let
  repoConfig = pkgs.writeText "atlantis-repo-config.yaml" ''
    repos:
      - id: codeberg.org/ScottyLabs/governance
        apply_requirements: [mergeable, undiverged]
        import_requirements: [mergeable, undiverged]
        allowed_overrides: [workflow, apply_requirements]
        allow_custom_workflows: true

    metrics:
      prometheus:
        endpoint: /metrics
  '';
in
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
      "--default-tf-distribution=opentofu"
      "--write-git-creds"
      "--allow-commands=version,plan,apply,unlock,approve_policies,cancel,import,state"
      "--silence-vcs-status-no-plans"
      "--hide-prev-plan-comments"
      "--enable-diff-markdown-format"
      "--repo-config=${repoConfig}"
    ];
  };

  age.secrets.atlantis = {
    file = ../../secrets/infra-01/atlantis.age;
    owner = "atlantis";
    mode = "0400";
  };
}
