{
  flake.modules.nixos.shell =
    {
      lib,
      pkgs,
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

      home-manager.users = lib.genAttrs (builtins.attrNames users) (_: {
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
      });
    };
}
