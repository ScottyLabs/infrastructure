{
  flake.modules.nixos.well-known =
    {
      config,
      lib,
      ...
    }:

    let
      cfg = config.scottylabs.matrix;

      clientConfig = {
        "m.homeserver".base_url = "https://${cfg.matrixDomain}";
        "m.identity_server" = { };
      };

      serverConfig = {
        "m.server" = "${cfg.matrixDomain}:443";
      };
    in
    {
      config = lib.mkIf cfg.enable {
        services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
          header /.well-known/matrix/* Content-Type application/json
          header /.well-known/matrix/* Access-Control-Allow-Origin *

          respond /.well-known/matrix/server `${builtins.toJSON serverConfig}` 200
          respond /.well-known/matrix/client `${builtins.toJSON clientConfig}` 200
        '';
      };
    };
}
