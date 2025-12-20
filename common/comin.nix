{ config, lib, comin, users, ... }:

{
  imports = [ comin.nixosModules.comin ];

  services.comin = {
    enable = true;

    gpgPublicKeyPaths = lib.attrValues (lib.mapAttrs (_: u: u.gpgPublicKeyFile) users);

    remotes = [{
      name = "origin";
      url = "https://github.com/ScottyLabs/infrastructure.git";
      branches.main.name = "main";
    }];
  };
}
