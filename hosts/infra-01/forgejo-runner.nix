{ config, lib, pkgs, ... }:

{
  age.secrets.forgejo-runner-token = {
    file = ../../secrets/infra-01/forgejo-runner-token.age;
    mode = "0400";
    owner = "gitea-runner";
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;

    instances.default = {
      enable = true;
      name = "infra-01";
      url = "https://codeberg.org";
      tokenFile = config.age.secrets.forgejo-runner-token.path;

      labels = [ "nix:docker://nixos/nix" ];

      settings = {
        runner.capacity = 2;
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
  users.groups.gitea-runner = {};

  systemd.services.gitea-runner-default.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "gitea-runner";
    Group = "gitea-runner";
  };
}
