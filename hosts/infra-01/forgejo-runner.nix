{ config, pkgs, ... }:

{
  age.secrets.forgejo-runner-token = {
    file = ../../secrets/infra-01/forgejo-runner-token.age;
    mode = "0400";
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    
    instances.default = {
      enable = true;
      name = "infra-01";
      url = "https://codeberg.org";
      tokenFile = config.age.secrets.forgejo-runner-token.path;
      
      labels = [ "nix:host" ];

      hostPackages = with pkgs; [
        bash
        coreutils
        git
        nix
        openssh
      ];

      settings = {
        runner.capacity = 2;
      };
    };
  };
}
