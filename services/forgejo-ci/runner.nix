{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.forgejoCI.runner;
in
let
  cfg = config.scottylabs.forgejoCI.runner;
  defaultJobImage = "scottylabs/act-runner:24.04";
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
        Local Docker image for `runs-on: docker` jobs. Built from
        ghcr.io/catthehacker/ubuntu:act-24.04 with a /var/run workaround for
        Docker 29.5.1 copyContent failures in act (moby#52655; fixed in 29.5.2).
      '';
    };

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "docker:docker://${defaultJobImage}" ];
      description = "Runner labels advertised to Forgejo. Defaults to jobImage when unchanged.";
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

    systemd.services.forgejo-act-runner-image = {
      description = "Build act runner image (/var/run workaround for Docker 29.5.1)";
      wantedBy = [ "multi-user.target" ];
      before = [ "gitea-runner-default.service" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [ docker ];
      script = ''
        set -euo pipefail
        if ! docker image inspect ${cfg.jobImage} >/dev/null 2>&1; then
          docker pull ghcr.io/catthehacker/ubuntu:act-24.04
          docker build -t ${cfg.jobImage} -f - <<'DOCKERFILE'
        FROM ghcr.io/catthehacker/ubuntu:act-24.04
        USER root
        RUN rm -f /var/run && mkdir -p /var/run
        DOCKERFILE
        fi
      '';
    };

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
