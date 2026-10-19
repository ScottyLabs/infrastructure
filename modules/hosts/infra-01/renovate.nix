{
  flake.modules.nixos.infra-01-renovate =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      kennelUrl = "https://git.cmu.dev/ScottyLabs/kennel";
      updateLockfiles = toString (
        pkgs.writeShellScript "update-lockfiles" ''
          set -euo pipefail
          if [ -f devenv.yaml ]; then
            # Renovate has no OpenBao token
            printf 'secretspec:\n  enable: false\n' > devenv.local.yaml
            ${lib.getExe pkgs.devenv} update
          fi
          if [ -f flake.nix ]; then
            nix flake update
          fi
        ''
      );
    in
    {
      age.secrets.renovate-token = {
        file = ../../../secrets/infra-01/renovate-token.age;
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

          enabledManagers = [
            "custom.regex"
            "nix"
          ];
          nix.enabled = true;
          lockFileMaintenance.enabled = true;

          # TODO: https://github.com/renovatebot/renovate/pull/40060
          customManagers = [
            {
              customType = "regex";
              managerFilePatterns = [ ''/devenv\.lock$/'' ];
              matchStrings = [
                ''"rev":\s*"(?<currentDigest>[a-f0-9]{40})",\s*"revCount":\s*\d+,\s*"type":\s*"git",\s*"url":\s*"https://git\.cmu\.dev/ScottyLabs/kennel"''
              ];
              currentValueTemplate = "main";
              depNameTemplate = "kennel";
              packageNameTemplate = kennelUrl;
              datasourceTemplate = "git-refs";
            }
          ];

          packageRules = [
            {
              matchManagers = [
                "nix"
                "custom.regex"
              ];
              groupName = "lockfiles";
              group.branchTopic = "lockfiles";
              schedule = [ "before 5am on Monday" ];
              commitMessageAction = "update";
              commitMessageTopic = "lockfiles";
              commitMessageExtra = "";
            }

            # Runs on kennel pushes via webhook.nix
            {
              matchPackageNames = [ kennelUrl ];
              groupName = "kennel";
              group = {
                branchTopic = "kennel";
                commitMessageTopic = "lockfiles";
              };
              schedule = [ "at any time" ];
            }
          ];

          allowedCommands = [ "^${lib.escapeRegex updateLockfiles}$" ];
          postUpgradeTasks = {
            commands = [ updateLockfiles ];
            fileFilters = [
              "devenv.lock"
              "flake.lock"
            ];
            executionMode = "branch";
          };
        };
      };
    };
}
