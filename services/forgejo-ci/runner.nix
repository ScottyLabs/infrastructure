{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.forgejoCI.runner;
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

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "docker:docker://ghcr.io/catthehacker/ubuntu:act-24.04" ];
      description = "Runner labels advertised to Forgejo.";
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
        tokenFile = cfg.tokenFile;
        labels = cfg.labels;

        settings = {
          runner.capacity = cfg.capacity;
          cache = {
            enabled = true;
            dir = "/var/lib/gitea-runner/cache";
            host = "0.0.0.0";
            port = cfg.cachePort;
            external_server = "http://host.docker.internal:${toString cfg.cachePort}";
          };
        };
      };
    };

    virtualisation.docker.enable = true;

    # Create a static user because gitea-actions-runner uses a dynamic one
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
