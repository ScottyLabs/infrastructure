{
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    {
      environment.systemPackages = with pkgs; [
        ragenix
        opentofu
      ];

      # Shell
      programs.zsh = {
        enable = true;
        enableCompletion = true;
      };

      users.defaultUserShell = pkgs.zsh;

      # SSH
      services.openssh.settings.PermitRootLogin = "no";

      # Non-wheel sudo for btrbk snapshots
      security.sudo.execWheelOnly = lib.mkForce false;

      # Regional
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";

      # Nix
      nix.package = pkgs.lixPackageSets.stable.lix;

      nix.gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
        persistent = true;
      };

      # Local journal buffer only, history ships to Loki via alloy
      services.journald.extraConfig = "SystemMaxUse=500M";

      assertions = [
        {
          assertion = config.disko.devices != { };
          message = "Each host must import a platform module that provides a disk configuration (e.g., campus-cloud)";
        }
      ];
    };
}
