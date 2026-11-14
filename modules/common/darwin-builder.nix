{ inputs, ... }:
let
  sshUser = "nix-builder";
  clientKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICT0EcqA77tSgR03MGQdxdfuizKW7DEvCRdSE1BtdJsx root@infra-01 darwin builder";
in
{
  # A Mac that builds aarch64-darwin for infra-01 (nixbot)
  flake.modules.darwin.darwin-builder =
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

  # Builds on every darwin host that has the darwin-builder module
  flake.modules.nixos.darwin-builder =
    { config, lib, ... }:

    let
      hostKeys = import ../../data/hosts.nix;
      builders = lib.filterAttrs (
        _: host: host.config.users.users ? ${sshUser}
      ) inputs.self.darwinConfigurations;
      fqdn = host: "${host.config.networking.hostName}.${host.config.scottylabs.domain}";
    in
    {
      age.secrets.darwin-builder-ssh-key = {
        file = ../../secrets/scottylabs/infra-01/darwin-builder-ssh-key.age;
        mode = "0400";
      };

      nix.buildMachines = lib.mapAttrsToList (_: host: {
        hostName = fqdn host;
        inherit sshUser;
        protocol = "ssh-ng";
        system = "aarch64-darwin";
        supportedFeatures = [
          "benchmark"
          "big-parallel"
          "nixos-test"
        ];
      }) builders;

      programs.ssh = {
        knownHosts = lib.mapAttrs (id: host: {
          hostNames = [ (fqdn host) ];
          publicKey = hostKeys.${id};
        }) builders;
        extraConfig = lib.concatMapStrings (host: ''
          Host ${fqdn host}
            # Don't hold a build slot waiting on a darwin builder
            ConnectTimeout 5
            IdentityFile ${config.age.secrets.darwin-builder-ssh-key.path}
        '') (lib.attrValues builders);
      };
    };
}
