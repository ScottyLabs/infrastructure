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
    # Use `handle`, not `handle_path`: both bridges register routes on the full
    # public URL path (mautrix-go: GET /_mautrix/publicmedia/…; mautrix-discord:
    # /mautrix-discord/avatar/…). Stripping the prefix yields 404/empty bodies
    # and Slack/Discord show blank profile pictures.
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
