{ config, lib, pkgs, users, ... }:

{
  users.users = builtins.mapAttrs (andrewId: userData: {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
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
        cat = "bat --style=plain --paging=never";
      };

      initContent = lib.mkMerge [
        (lib.mkBefore ''
          zstyle ':omz:plugins:eza' 'git-status' yes
          zstyle ':omz:plugins:eza' 'icons' yes
        '')
        ''
          pfetch
        ''
      ];

      oh-my-zsh = {
        enable = true;
        plugins = [ "eza" ];
      };
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    programs.git = {
      enable = true;
      signing = {
        format = "openpgp";
        key = userData.gpgFingerprint;
        signByDefault = true;
      };
      settings = {
        user = userData.git;
        init.defaultBranch = "main";
        tag.gpgSign = true;
        safe.directory = "/etc/nixos"; # trust this directory for operations
      };
    };
  }) users;
}
