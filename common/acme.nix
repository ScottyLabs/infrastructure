{ config, ... }:

{
  age.secrets.acme-credentials = {
    file = ../secrets/acme-credentials.age;
    mode = "0400";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@scottylabs.org";
      server = "https://acme.sectigo.com/v2/InCommonRSAOV";
      environmentFile = config.age.secrets.acme-credentials.path;
      extraLegoFlags = [ "--eab" ];
    };
  };
}
