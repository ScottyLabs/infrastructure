{
  flake.modules.nixos.public-ip =
    { lib, ... }:
    {
      options.scottylabs.publicIp = lib.mkOption {
        type = lib.types.str;
        description = "Externally allocated public IP for this host";
      };
    };
}
