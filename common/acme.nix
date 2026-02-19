{ config, ... }:

{
  age.secrets.cloudflare-api-token = {
    file = ../secrets/cloudflare-api-token.age;
    mode = "0400";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@scottylabs.org";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets.cloudflare-api-token.path;
    };
  };
}
