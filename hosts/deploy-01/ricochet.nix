{ ricochet, ... }:

{
  imports = [
    ricochet.nixosModules.default
  ];

  services.ricochet = {
    enable = true;
    package = ricochet.packages.x86_64-linux.ricochet;
    bind = "127.0.0.1:8090";
    allowedHosts = [ "*.scottylabs.net" ];
  };

  services.caddy.virtualHosts."oauth.scottylabs.org".extraConfig = ''
    reverse_proxy 127.0.0.1:8090
  '';
}
