let
  features = [
    "benchmark"
    "big-parallel"
    "ca-derivations"
    "nixos-test"
    "uid-range"
  ];
in
{
  flake.modules.nixos.scottylabs-infra-01-nixbuild =
    { config, ... }:

    {
      age.secrets.nixbuild-ssh-key = {
        file = ../../../../secrets/scottylabs/infra-01/nixbuild-ssh-key.age;
        mode = "0400";
      };

      nix = {
        distributedBuilds = true;
        buildMachines = [
          {
            hostName = "eu.nixbuild.net";
            protocol = "ssh-ng";
            system = "x86_64-linux";
            maxJobs = 100;
            supportedFeatures = features ++ [ "kvm" ];
          }
          {
            hostName = "eu.nixbuild.net";
            protocol = "ssh-ng";
            system = "aarch64-linux";
            maxJobs = 100;
            supportedFeatures = features;
          }
        ];

        settings.builders-use-substitutes = true;
      };

      programs.ssh = {
        knownHosts.nixbuild = {
          hostNames = [ "eu.nixbuild.net" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
        };
        # Lets root reach the nixbuild.net admin shell
        extraConfig = ''
          Host eu.nixbuild.net
            ServerAliveInterval 60
            IdentityFile ${config.age.secrets.nixbuild-ssh-key.path}
        '';
      };
    };
}
