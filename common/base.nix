{
  lib,
  pkgs,
  hostname,
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

  # Networking
  networking.hostName = hostname;

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
}
