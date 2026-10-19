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
      updateDevenvLock = toString (
        pkgs.writeShellScript "update-devenv-lock" ''
          [ -f devenv.yaml ] || exit 0
          # Renovate has no OpenBao token
          printf 'secretspec:\n  enable: false\n' > devenv.local.yaml
          ${lib.getExe pkgs.devenv} update "$@"
        ''
      );
      # packageRules entries don't merge postUpgradeTasks
      postUpgradeTasks = command: {
        commands = [ command ];
        fileFilters = [ "devenv.lock" ];
        executionMode = "branch";
      };
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
              postUpgradeTasks = postUpgradeTasks updateDevenvLock;
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
              postUpgradeTasks = postUpgradeTasks "${updateDevenvLock} scottylabs";
            }
          ];

          allowedCommands = [ "^${lib.escapeRegex updateDevenvLock}( scottylabs)?$" ];
        };
      };
    };
}
