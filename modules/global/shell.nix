{ config, ... }:
{
  flake.modules.nixos.shell =
    {
      lib,
      users,
      ...
    }:

    {
      users.users =
        (builtins.mapAttrs (_: key: {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "docker"
          ];
          openssh.authorizedKeys.keys = [ key ];
        }) users)
        // {
          deploy = {
            isNormalUser = true;
            openssh.authorizedKeys.keys = builtins.attrValues users;
          };
        };

      security.sudo.extraRules = [
        {
          users = [ "deploy" ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
      nix.settings.trusted-users = [ "deploy" ];

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";

      home-manager.users = lib.genAttrs (builtins.attrNames users) (
        _: config.flake.modules.homeManager.shell
      );
    };

  flake.modules.darwin.shell =
    { users, ... }:
    {
      # deploy account colmena connects as
      users.knownUsers = [ "deploy" ];
      users.users.deploy = {
        uid = 550;
        gid = 20;
        home = "/Users/deploy";
        createHome = true;
        shell = "/bin/zsh";
        ignoreShellProgramCheck = true;
        openssh.authorizedKeys.keys = builtins.attrValues users;
      };

      security.sudo.extraConfig = "deploy ALL=(ALL) NOPASSWD: ALL";

      nix.settings.trusted-users = [ "deploy" ];

      # grant deploy SSH access when Remote Login is restricted to specific users
      system.activationScripts.postActivation.text = ''
        if /usr/sbin/dseditgroup -o read com.apple.access_ssh >/dev/null 2>&1; then
          /usr/sbin/dseditgroup -o edit -a deploy -t user com.apple.access_ssh
        fi
      '';

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";

      home-manager.users.deploy = config.flake.modules.homeManager.shell;
    };

  flake.modules.homeManager.shell =
    { lib, pkgs, ... }:
    {
      home.stateVersion = "25.11";
      home.packages = with pkgs; [
        eza
        bat
        fastfetch
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
            fastfetch
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
    };
}
