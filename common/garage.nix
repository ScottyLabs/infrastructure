{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.garage;
in
{
  options.scottylabs.garage = {
    enable = lib.mkEnableOption "Garage S3-compatible object storage";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to environment file containing:
        - GARAGE_RPC_SECRET=<32-byte hex string>
        - GARAGE_ADMIN_TOKEN=<admin bearer token>
      '';
    };

    s3Port = lib.mkOption {
      type = lib.types.port;
      default = 3900;
      description = "Port for the S3 API";
    };

    rpcPort = lib.mkOption {
      type = lib.types.port;
      default = 3901;
      description = "Port for internal RPC";
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 3903;
      description = "Port for the admin API";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "s3.scottylabs.org";
      description = "Domain name for the S3 API endpoint";
    };
  };

  config = lib.mkIf cfg.enable {
    services.garage = {
      enable = true;
      package = pkgs.garage_2;

      inherit (cfg) environmentFile;

      settings = {
        replication_factor = 1;

        rpc_bind_addr = "[::]:${toString cfg.rpcPort}";

        s3_api = {
          s3_region = "us-east-1";
          api_bind_addr = "[::]:${toString cfg.s3Port}";
        };

        admin = {
          api_bind_addr = "[::]:${toString cfg.adminPort}";
        };
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString cfg.s3Port}";
        };
      };
    };
  };
}
