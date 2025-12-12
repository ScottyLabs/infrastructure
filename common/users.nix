{ config, pkgs, users, ... }:

{
  users.users = builtins.mapAttrs (andrewId: userData: {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  }) users;

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
      signing = {
        key = "key::${userData.sshPublicKey}";
        format = "ssh";
        signByDefault = true;
      };
      settings = {
        user = userData.git;
        init = {
          defaultBranch = "main";
        };
        safe.directory = "/etc/nixos"; # trust this directory for operations
      };
    };
  }) users;
}
