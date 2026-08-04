{
  flake.modules.nixos.infra-01-renovate =
    { config, pkgs, ... }:

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

        runtimePackages = [
          pkgs.nix
          pkgs.devenv
        ];

        settings = {
          platform = "forgejo";
          endpoint = "https://git.cmu.dev";
          gitAuthor = "scottylabs-bot <ops+cmu-dev@scottylabs.org>";
          autodiscover = true;
          autodiscoverFilter = [ "ScottyLabs/*" ];

          onboarding = false;
          requireConfig = "optional";

          enabledManagers = [
            "custom.regex"
            "nix"
          ];

          allowedCommands = [ "^devenv update$" ];

          commitMessagePrefix = "chore: ";

          nix.enabled = true;

          lockFileMaintenance = {
            enabled = true;
            schedule = [ "before 5am on Monday" ];
            commitMessageAction = "update lockfiles";
          };

          customManagers = [
            {
              customType = "regex";
              managerFilePatterns = [ ''/devenv\.lock$/'' ];
              matchStrings = [
                ''"rev":\s*"(?<currentDigest>[a-f0-9]{40})",\s*"revCount":\s*\d+,\s*"type":\s*"git",\s*"url":\s*"https://git\.cmu\.dev/ScottyLabs/kennel"''
              ];
              currentValueTemplate = "main";
              depNameTemplate = "scottylabs-devenv";
              packageNameTemplate = "https://git.cmu.dev/ScottyLabs/kennel";
              datasourceTemplate = "git-refs";
            }
          ];

          postUpgradeTasks = {
            commands = [ "devenv update" ];
            fileFilters = [ "devenv.lock" ];
            executionMode = "branch";
          };
        };
      };
    };
}
