let
  sshUser = "nix-builder";
  clientKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICT0EcqA77tSgR03MGQdxdfuizKW7DEvCRdSE1BtdJsx root@infra-01 darwin builder";
in
{
  flake.modules.darwin.infra-02-builder =
    { config, ... }:

    {
      users.knownUsers = [ sshUser ];
      users.users.${sshUser} = {
        uid = 551;
        shell = "/bin/zsh";
        openssh.authorizedKeys.keys = [
          ''command="${config.nix.package}/bin/nix-daemon --stdio",restrict ${clientKey}''
        ];
      };

      # Lets infra-01 copy unsigned build inputs here
      nix.settings.trusted-users = [ sshUser ];

      system.activationScripts.postActivation.text = ''
        if /usr/sbin/dseditgroup -o read com.apple.access_ssh >/dev/null 2>&1; then
          /usr/sbin/dseditgroup -o edit -a ${sshUser} -t user com.apple.access_ssh
        fi
      '';
    };

  flake.modules.nixos.infra-01-darwin-builder =
    { config, ... }:

    {
      age.secrets.infra-02-builder-ssh-key = {
        file = ../../../secrets/infra-01/infra-02-builder-ssh-key.age;
        mode = "0400";
      };

      nix.buildMachines = [
        {
          hostName = "infra-02.scottylabs.org";
          inherit sshUser;
          protocol = "ssh-ng";
          system = "aarch64-darwin";
          supportedFeatures = [
            "benchmark"
            "big-parallel"
            "nixos-test"
          ];
        }
      ];

      programs.ssh = {
        knownHosts.infra-02 = {
          hostNames = [ "infra-02.scottylabs.org" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXn1GdJYesQxj4Bq+vz+ZITAuWIeOZZkMHsjMbY1IeW";
        };
        extraConfig = ''
          Host infra-02.scottylabs.org
            # Don't hold a build slot waiting on infra-02
            ConnectTimeout 5
            IdentityFile ${config.age.secrets.infra-02-builder-ssh-key.path}
        '';
      };
    };
}
