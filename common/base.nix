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

  # btrbk needs sudo as a non-wheel user for btrfs snapshot commands
  security.sudo.execWheelOnly = lib.mkForce false;

  # Networking
  networking.hostName = hostname;

  # Regional
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # nh and garbage collection
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.dates = "daily";
    clean.extraArgs = "--keep-since 7d --keep 1";
    flake = "/etc/nixos";
  };

  # Add alias for nixos-rebuild switch using nh
  environment.shellAliases = {
    update = "sudo btrbk run && nh os switch";
    rollback = "nh os switch --rollback";
  };

  # Nix
  nix.package = pkgs.lixPackageSets.stable.lix;

  # nh doesn't touch comin sub-profiles
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
    persistent = true;
  };
}
