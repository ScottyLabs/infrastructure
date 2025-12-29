{ config, lib, comin, ... }:

{
  imports = [ comin.nixosModules.comin ];

  services.comin = {
    enable = true;

    # We use SSH keys for signing commits because gpg key forwarding is
    # complicated to set up. Once SSH key signing is supported by comin
    # (https://github.com/nlewo/comin/issues/73), we can switch to that.

    # gpgPublicKeyPaths = lib.mapAttrsToList (_: u: toString u.gpgPublicKeyFile) users;

    remotes = [{
      name = "origin";
      url = "https://codeberg.org/ScottyLabs/infrastructure.git";
      branches.main.name = "main";
    }];
  };
}
