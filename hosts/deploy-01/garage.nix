{ config, ... }:

{
  # Backs kennel's per-deployment object storage
  scottylabs.garage = {
    enable = true;
    domain = "s3.kennel.scottylabs.org";
    environmentFile = config.age.secrets.garage.path;
  };

  age.secrets.garage = {
    file = ../../secrets/deploy-01/garage.age;
    mode = "0400";
  };
}
