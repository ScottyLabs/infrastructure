# Public HTTP routes on the Matrix client domain so Slack/Discord can fetch avatar URLs.
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
    services.caddy.virtualHosts.${cfg.matrixDomain}.extraConfig = lib.mkBefore ''
      handle_path /_mautrix/publicmedia/* {
        reverse_proxy 127.0.0.1:${toString slackAppservicePort}
      }
      handle_path /mautrix-discord/* {
        reverse_proxy 127.0.0.1:${toString discordAppservicePort}
      }
    '';
  };
}
