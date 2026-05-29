{ config, ... }:

{
  age.secrets.matrix-registration = {
    file = ../../secrets/infra-01/matrix-registration.age;
    owner = "matrix-synapse";
    mode = "0400";
  };

  age.secrets.double-puppet = {
    file = ../../secrets/infra-01/double-puppet.age;
    owner = "matrix-synapse";
    mode = "0400";
  };

  age.secrets.double-puppet-env = {
    file = ../../secrets/infra-01/double-puppet-env.age;
    owner = "mautrix-discord";
    mode = "0400";
  };

  age.secrets.double-puppet-env-slack = {
    file = ../../secrets/infra-01/double-puppet-env.age;
    owner = "mautrix-slack";
    mode = "0400";
  };

  scottylabs.matrix = {
    enable = true;
    domain = "doggylabs.org";

    synapse = {
      registrationSecretFile = config.age.secrets.matrix-registration.path;
      extraConfigFile = config.age.secrets.double-puppet.path;
    };

    bridges.discord = {
      enable = true;
      environmentFile = config.age.secrets.double-puppet-env.path;
      adminUsers = [
        "@ap-1:matrix.org"
        "@reconciler:doggylabs.org"
        "@thesuperrl:matrix.org"
      ];
    };

    bridges.slack = {
      enable = true;
      environmentFile = config.age.secrets.double-puppet-env-slack.path;
      # Relay login ID lives in double-puppet-env.age as SLACK_RELAY_LOGIN_ID (login app, not token).
      relay.enable = true;
      adminUsers = [
        "@ap-1:matrix.org"
        "@reconciler:doggylabs.org"
        "@thesuperrl:matrix.org"
      ];
    };
  };
}
