{ config, pkgs, ... }:

let
  devops = {
    # Format: andrewid = { name = "git name", email = "git email"; };

    apallati = { name = "Anish Pallati"; email = "i@anish.land"; };
    jefferyo = { name = "Jeffery Oo"; email = "jefferyo@andrew.cmu.edu"; };
  };
in
{
  users.users = builtins.mapAttrs (andrewId: userData: {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  }) devops;

  home-manager.users = builtins.mapAttrs (andrewId: userData: {
    home.stateVersion = "25.05";
    programs.git = {
      enable = true;
      userName = userData.name;
      userEmail = userData.email;
      extraConfig = {
        safe.directory = "/etc/nixos"; # trust this directory for operations
      };
    };
  }) devops;
}

