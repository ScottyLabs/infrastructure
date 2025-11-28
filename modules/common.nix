{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  services.openssh.enable = true;

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
  security.pam.services.sshd.makeHomeDir = true;

  # Maintain /etc/nixos permissions for shared access
  system.activationScripts.etcNixosPermissions = ''
    if [ -d /etc/nixos ]; then
      chgrp -R wheel /etc/nixos
      chmod -R g+w /etc/nixos
    fi
  '';
}

