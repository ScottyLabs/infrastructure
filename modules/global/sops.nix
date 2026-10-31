{
  flake.modules.nixos.sops =
    { config, ... }:

    {
      # Readable by this host and the admins, see the rules in devenv.nix
      sops.defaultSopsFile = ../../secrets/${config.scottylabs.organization}/${config.networking.hostName}.yaml;
    };
}
