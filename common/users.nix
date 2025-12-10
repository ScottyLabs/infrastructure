{ config, pkgs, userWhitelist, ... }:

{
  users.users = builtins.mapAttrs (andrewId: userData: {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  }) userWhitelist;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  home-manager.users = builtins.mapAttrs (andrewId: userData: {
    home.stateVersion = "25.11";
    home.packages = with pkgs; [
      eza
      bat
      pfetch
    ];

    programs.zsh = {
      enable = true;
      enableCompletion = true;

      shellAliases = {
        ls = "eza";
        cat = "bat --style=plain --paging=never";
      };
      initContent = ''
        pfetch
      '';
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
    };

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
