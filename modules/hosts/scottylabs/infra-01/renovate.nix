{
  flake.modules.nixos.scottylabs-infra-01-renovate =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      updateLockfiles = toString (
        pkgs.writeShellScript "update-lockfiles" ''
          set -euo pipefail
          if [ -f flake.nix ]; then
            nix flake update
          fi
        ''
      );
    in
    {
      age.secrets.renovate-token = {
        file = ../../../../secrets/scottylabs/infra-01/renovate-token.age;
      };

      services.renovate = {
        enable = true;
        schedule = "weekly";

        credentials = {
          RENOVATE_TOKEN = config.age.secrets.renovate-token.path;
        };

        runtimePackages = [ config.nix.package ];

        settings = {
          platform = "forgejo";
          endpoint = "https://git.cmu.dev";
          gitAuthor = "scottylabs-bot <ops+cmu-dev@scottylabs.org>";
          autodiscover = true;
          autodiscoverFilter = [ "ScottyLabs/*" ];
          onboarding = false;
          requireConfig = "optional";

          semanticCommits = "enabled";
          semanticCommitScope = null;
          # Drops the emoji config summary, header and footer
          prBodyTemplate = "{{{table}}}{{{warnings}}}{{{notes}}}{{{changelogs}}}{{{controls}}}";
          automerge = true;
          automergeStrategy = "fast-forward";
          # Renovate merges in the same run instead of Forgejo waiting on CI
          platformAutomerge = false;
          ignoreTests = true;
          # a merged PR with the same title otherwise disables automerge
          recreateWhen = "always";

          enabledManagers = [ "nix" ];
          nix.enabled = true;
          lockFileMaintenance.enabled = true;

          packageRules = [
            {
              matchManagers = [ "nix" ];
              groupName = "lockfiles";
              group.branchTopic = "lockfiles";
              schedule = [ "before 5am on Monday" ];
              commitMessageAction = "update";
              commitMessageTopic = "lockfiles";
              commitMessageExtra = "";
            }
          ];

          allowedCommands = [ "^${lib.escapeRegex updateLockfiles}$" ];
          postUpgradeTasks = {
            commands = [ updateLockfiles ];
            fileFilters = [ "flake.lock" ];
            executionMode = "branch";
          };
        };
      };
    };
}
