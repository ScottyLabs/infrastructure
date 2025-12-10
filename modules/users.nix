{ config, pkgs, userWhitelist, ... }:

{
  users.users = builtins.mapAttrs (andrewId: userData: {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  }) userWhitelist;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users = builtins.mapAttrs (andrewId: userData: {
    home.stateVersion = "25.11";

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = userData.gitName;
          email = userData.gitEmail;
        };
        init = {
          defaultBranch = "main";
        };
        safe.directory = "/etc/nixos"; # trust this directory for operations
      };
    };
  }) userWhitelist;
}
