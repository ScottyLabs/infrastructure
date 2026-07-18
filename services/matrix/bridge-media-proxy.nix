{
  config,
  lib,
  ...
}:

let
  cfg = config.scottylabs.matrix;
  slackAppservicePort = 29335;
  discordAppservicePort = 29334;
in
{
  config = lib.mkIf (cfg.enable && cfg.bridges.slack.enable && cfg.bridges.discord.enable) {
    # Serve bridge public media on the matrix domain
    services.caddy.virtualHosts.${cfg.matrixDomain}.extraConfig = lib.mkBefore ''
      handle /_mautrix/publicmedia/* {
        reverse_proxy 127.0.0.1:${toString slackAppservicePort}
      }
      handle /mautrix-discord/* {
        reverse_proxy 127.0.0.1:${toString discordAppservicePort}
      }
    '';
  };
}
