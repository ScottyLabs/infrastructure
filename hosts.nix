# Hosts by organization, read by modules/systems.nix and the sops rules in devenv.nix
{
  scottylabs = {
    infra-01 = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
    };
    infra-02 = {
      domain = "scottylabs.org";
      system = "aarch64-darwin";
    };
    infra-03 = {
      domain = "scottylabs.org";
      system = "aarch64-linux";
    };
    deploy-01 = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
    };
    signage-01 = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
    };
    snoopy = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
    };
  };
  stugov = {
    elect-01 = {
      domain = "andrew.cmu.edu";
      system = "x86_64-linux";
    };
  };
  thetartan = {
    tartan-01 = {
      domain = "andrew.cmu.edu";
      system = "x86_64-linux";
    };
  };
}
