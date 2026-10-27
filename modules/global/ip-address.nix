let
  ipAddress =
    { lib, ... }:
    {
      options.scottylabs.ipAddress = lib.mkOption {
        type = lib.types.str;
        description = "IP address this host's DNS A record targets";
      };

      options.scottylabs.bastion = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Jump host FQDN for LAN-only nodes unreachable directly from a deployer";
      };

      options.scottylabs.organization = lib.mkOption {
        type = lib.types.str;
        description = "Organization this host belongs to, such as scottylabs";
      };

      options.scottylabs.domain = lib.mkOption {
        type = lib.types.str;
        description = "DNS domain under which this host's A record lives";
      };
    };
in
{
  flake.modules.nixos.ip-address = ipAddress;
  flake.modules.darwin.ip-address = ipAddress;
}
