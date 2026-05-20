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
      adminUsers = [ "@ap-1:matrix.org" ];
    };
  };
}
