{
  flake.modules.nixos.scottylabs-infra-01-matrix =
    { config, ... }:

    {
      age.secrets.matrix-registration = {
        file = ../../../../../secrets/scottylabs/infra-01/matrix-registration.age;
        owner = "matrix-synapse";
        mode = "0400";
      };

      age.secrets.double-puppet = {
        file = ../../../../../secrets/scottylabs/infra-01/double-puppet.age;
        owner = "matrix-synapse";
        mode = "0400";
      };

      age.secrets.double-puppet-env = {
        file = ../../../../../secrets/scottylabs/infra-01/double-puppet-env.age;
        owner = "mautrix-discord";
        mode = "0400";
      };

      age.secrets.double-puppet-env-slack = {
        file = ../../../../../secrets/scottylabs/infra-01/double-puppet-env.age;
        owner = "mautrix-slack";
        mode = "0400";
      };

      age.secrets.bridge-identity = {
        file = ../../../../../secrets/scottylabs/infra-01/bridge-identity-sync.age;
        mode = "0400";
      };

      sops.secrets = {
        matrix-registration = {
          owner = "matrix-synapse";
          restartUnits = [ "matrix-synapse.service" ];
        };
        double-puppet = {
          owner = "matrix-synapse";
          restartUnits = [ "matrix-synapse.service" ];
        };
        double-puppet-env = {
          owner = "mautrix-discord";
          restartUnits = [ "mautrix-discord.service" ];
        };
        double-puppet-env-slack = {
          key = "double-puppet-env";
          owner = "mautrix-slack";
          restartUnits = [ "mautrix-slack.service" ];
        };
        bridge-identity = {
          key = "bridge-identity-sync";
          restartUnits = [
            "mautrix-discord.service"
            "mautrix-slack.service"
          ];
        };
      };

      scottylabs.matrix = {
        enable = true;
        domain = "doggylabs.org";

        synapse = {
          registrationSecretFile = config.sops.secrets.matrix-registration.path;
          extraConfigFile = config.sops.secrets.double-puppet.path;
        };

        bridges.discord = {
          enable = true;
          environmentFile = config.sops.secrets.double-puppet-env.path;
          relayLoginId = "@reconciler:doggylabs.org";
          adminUsers = [
            "@ap-1:matrix.org"
            "@reconciler:doggylabs.org"
            "@thesuperrl:matrix.org"
          ];
        };

        bridgeIdentity = {
          enable = true;
          environmentFile = config.sops.secrets.bridge-identity.path;
        };

        bridges.slack = {
          enable = true;
          environmentFile = config.sops.secrets.double-puppet-env-slack.path;
          # Relay login ID in the double-puppet-env secret as SLACK_RELAY_LOGIN_ID
          relay.enable = true;
          adminUsers = [
            "@ap-1:matrix.org"
            "@reconciler:doggylabs.org"
            "@thesuperrl:matrix.org"
          ];
        };
      };
    };
}
