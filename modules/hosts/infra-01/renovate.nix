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

        runtimePackages = [ pkgs.nix pkgs.devenv ];

        settings = {
          platform = "forgejo";
          endpoint = "https://codeberg.org";
          gitAuthor = "scottylabs-bot <ops+codeberg@scottylabs.org>";
          autodiscover = true;
          autodiscoverFilter = [ "ScottyLabs/*" ];

          onboarding = false;
          requireConfig = "optional";

          enabledManagers = [ "custom.regex" "nix" ];

          allowedCommands = [ "^devenv update$" ];

          commitMessagePrefix = "chore(deps): ";

          nix.enabled = true;

          lockFileMaintenance = {
            enabled = true;
            schedule = [ "before 5am on Monday" ];
            commitMessageAction = "lock file maintenance";
          };

          customManagers = [
            {
              customType = "regex";
              managerFilePatterns = [ ''/devenv\.lock$/'' ];
              matchStrings = [
                ''"rev":\s*"(?<currentDigest>[a-f0-9]{40})",\s*"revCount":\s*\d+,\s*"type":\s*"git",\s*"url":\s*"https://codeberg\.org/ScottyLabs/devenv"''
              ];
              currentValueTemplate = "main";
              depNameTemplate = "scottylabs-devenv";
              packageNameTemplate = "https://codeberg.org/ScottyLabs/devenv";
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
