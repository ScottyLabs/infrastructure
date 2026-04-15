{ terrier, ... }:

let
  terrierDocs = terrier.packages.x86_64-linux.terrierDocs;
in
{
  services.caddy.virtualHosts."docs.terrier.build".extraConfig = ''
    root * ${terrierDocs}
    file_server
  '';
}
