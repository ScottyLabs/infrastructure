{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.forgejoCI.runner;
  defaultJobImage = "ghcr.io/catthehacker/ubuntu:act-24.04";
  runnerLabels = [ "docker:docker://${cfg.jobImage}" ];
in
{
  options.scottylabs.forgejoCI.runner = {
    enable = lib.mkEnableOption "Forgejo Actions runner with a static user and docker access";

    name = lib.mkOption {
      type = lib.types.str;
      description = "Runner instance name registered with the Forgejo server.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://codeberg.org";
      description = "Forgejo server URL.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file containing the runner registration token.";
    };

    jobImage = lib.mkOption {
      type = lib.types.str;
      default = defaultJobImage;
      description = ''
        Docker image used for `runs-on: docker` jobs. Pulled automatically by
        the runner; the upstream catthehacker image provides a GitHub
        Actions-compatible environment.
      '';
    };

    capacity = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Maximum concurrent jobs.";
    };

    cachePort = lib.mkOption {
      type = lib.types.port;
      default = 8088;
      description = "Port for the runner-side Actions cache server.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;

      instances.default = {
        enable = true;
        inherit (cfg) name url;
        inherit (cfg) tokenFile;
        labels = runnerLabels;

        settings = {
          runner = {
            inherit (cfg) capacity;
            labels = runnerLabels;
          };
          cache = {
            enabled = true;
            dir = "/var/lib/gitea-runner/cache";
            # docker0 gateway
            host = "172.17.0.1";
            port = cfg.cachePort;
          };
          container = {
            network = "bridge";
          };
        };
      };
    };

    # Pin docker0 and per-job networks to fixed subnets clear of CMU-SECURE space
    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        bip = "172.17.0.1/16";
        default-address-pools = [
          {
            base = "10.89.0.0/16";
            size = 24;
          }
        ];
      };
    };

    networking.firewall.trustedInterfaces = [ "docker0" ];

    # Static user for the runner
    users.users.gitea-runner = {
      isSystemUser = true;
      group = "gitea-runner";
      extraGroups = [ "docker" ];
      home = "/var/lib/gitea-runner";
    };
    users.groups.gitea-runner = { };

    systemd.services.gitea-runner-default.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "gitea-runner";
      Group = "gitea-runner";
    };
  };
}
