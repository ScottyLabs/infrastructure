{ config, pkgs, hostname, users, neovim-nightly-overlay, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    curl
    ghostty.terminfo
    ragenix
  ];

  # Shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  users.defaultUserShell = pkgs.zsh;

  # Neovim
  programs.neovim = {
    enable = true;
    package = neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # KbdInteractiveAuthentication used instead
      PermitRootLogin = "no"; # shouldn't SSH directly as root
      AllowUsers = builtins.attrNames users;
    };
  };

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  # Regional
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Kerberos client for CMU
  security.krb5 = {
    enable = true;
    settings = {
      libdefaults.default_realm = "ANDREW.CMU.EDU";
      realms."ANDREW.CMU.EDU" = {
        kdc = "kerberos.andrew.cmu.edu";
        admin_server = "kerberos.andrew.cmu.edu";
      };
    };
  };

  # PAM Kerberos integration
  security.pam = {
    krb5.enable = true;
    services.sshd.makeHomeDir = true;
  };

  # Maintain /etc/nixos permissions for shared access
  system.activationScripts.etcNixosPermissions = ''
    if [ -d /etc/nixos ]; then
      chgrp -R wheel /etc/nixos
      chmod -R g+w /etc/nixos
    fi
  '';

  # nh and garbage collection
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 3";
    flake = "/etc/nixos";
  };

  # Add alias for nixos-rebuild switch using nh
  environment.shellAliases = {
    update = "sudo btrbk run && nh os switch";
    rollback = "nh os switch --rollback";
  };

  # Nix
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 536870912; # 512 MiB
  };
}
