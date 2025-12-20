{ config, lib, comin, users, ... }:

{
  imports = [ comin.nixosModules.comin ];

  services.comin = {
    enable = true;

    gpgPublicKeyPaths = lib.mapAttrsToList (_: u: toString u.gpgPublicKeyFile) users;

    remotes = [{
      name = "origin";
      url = "https://github.com/ScottyLabs/infrastructure.git";
      branches.main.name = "main";
    }];
  };
}
