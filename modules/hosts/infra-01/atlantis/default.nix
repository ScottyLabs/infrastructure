{ config, ... }:
{
  flake.modules.nixos.infra-01-atlantis =
    { config, pkgs, ... }:

    {
      scottylabs.atlantis = {
        enable = true;
        domain = "atlantis.scottylabs.org";
        environmentFile = config.age.secrets.atlantis.path;
        extraPackages = [
          pkgs.opentofu
          pkgs.nix
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
          "--repo-allowlist=codeberg.org/ScottyLabs/governance,codeberg.org/ScottyLabs/infrastructure"
          "--allow-fork-prs"
          "--default-tf-distribution=opentofu"
          "--write-git-creds"
          "--allow-commands=all"
          "--silence-vcs-status-no-plans"
          "--hide-prev-plan-comments"
          "--enable-diff-markdown-format"
          "--fail-on-pre-workflow-hook-error"
          "--repo-config=${./repo-config.yml}"
        ];
      };

      age.secrets.atlantis = {
        file = ../../../../secrets/infra-01/atlantis.age;
        owner = "atlantis";
        mode = "0400";
      };

      systemd.services.atlantis.serviceConfig.EnvironmentFile = [
        config.age.secrets.tofu-providers.path
      ];

      systemd.services.atlantis.environment = {
        TF_PLUGIN_CACHE_DIR = "/var/lib/atlantis/plugin-cache";
        TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE = "1";
      };

      systemd.tmpfiles.rules = [ "d /var/lib/atlantis/plugin-cache 0755 atlantis atlantis -" ];
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.atlantis = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          {
            terraform.backend.s3.key = "services/atlantis.tfstate";
            dns.atlantis = {
              host = "infra-01";
              type = "CNAME";
              comment = "Atlantis OpenTofu PR automation";
            };
          }
        ];
      };
    };
}
