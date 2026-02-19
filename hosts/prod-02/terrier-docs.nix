{ terrier, ... }:

let
  terrierDocs = terrier.packages.x86_64-linux.terrierDocs;
in
{
  services.nginx.virtualHosts."docs.terrier.build" = {
    enableACME = true;
    forceSSL = true;
    root = terrierDocs;
    locations."/" = {
      tryFiles = "$uri $uri/ =404";
    };
  };
}
