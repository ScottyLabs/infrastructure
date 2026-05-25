{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.scottylabs.matrix.reconciler;

  reconcilerScript = pkgs.writeScriptBin "matrix-reconciler" ''
    #!${pkgs.python3}/bin/python3
    import asyncio
    import json
    import os
    import sys

    from nio import AsyncClient, RoomCreateError, RoomInviteError

    HOMESERVER = os.environ.get("MATRIX_HOMESERVER", "https://matrix.doggylabs.org")
    ADMIN_TOKEN = os.environ.get("MATRIX_ADMIN_TOKEN")
    SLACK_BOT = os.environ.get("SLACK_BOT_ID", "@slack:doggylabs.org")
    DISCORD_BOT = os.environ.get("DISCORD_BOT_ID", "@discord:doggylabs.org")
    DOMAIN = os.environ.get("MATRIX_DOMAIN", "doggylabs.org")
    DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"


    class MatrixReconciler:
        def __init__(self):
            if not ADMIN_TOKEN:
                raise ValueError("MATRIX_ADMIN_TOKEN must be set")
            self.client = AsyncClient(HOMESERVER)
            self.client.access_token = ADMIN_TOKEN

        async def ensure_room_exists(self, alias: str, name: str):
            room_alias = f"#{alias}:{DOMAIN}"
            try:
                resp = await self.client.room_resolve_alias(room_alias)
                if resp.room_id:
                    print(f"Room {room_alias} exists: {resp.room_id}")
                    return resp.room_id
            except Exception:
                pass

            if DRY_RUN:
                print(f"[DRY RUN] Would create room {room_alias} ({name})")
                return None

            print(f"Creating room {room_alias} ({name})")
            resp = await self.client.room_create(
                alias=alias,
                name=name,
                topic="Mirrored Slack and Discord channel via Matrix",
                visibility="private",
                invite=[SLACK_BOT, DISCORD_BOT],
            )
            if isinstance(resp, RoomCreateError):
                print(f"Failed to create room: {resp.message}")
                return None
            print(f"Created room {resp.room_id}")
            return resp.room_id

        async def invite_bot(self, room_id: str, bot_id: str):
            if DRY_RUN:
                print(f"[DRY RUN] Would invite {bot_id} to {room_id}")
                return
            resp = await self.client.room_invite(room_id, bot_id)
            if isinstance(resp, RoomInviteError):
                print(f"Note: Could not invite {bot_id} to {room_id}: {resp.message}")
            else:
                print(f"Invited {bot_id} to {room_id}")

        async def send_bridge_command(self, room_id: str, channel_id: str):
            if DRY_RUN:
                print(f"[DRY RUN] Would send bridge {channel_id} in {room_id}")
                return
            await self.client.room_send(
                room_id=room_id,
                message_type="m.room.message",
                content={"msgtype": "m.text", "body": f"bridge {channel_id}"},
            )
            print(f"Sent bridge command for channel {channel_id} in {room_id}")

        async def reconcile_channel_pair(self, pair: dict):
            team_name = pair.get("team_name", "Unknown")
            team_slug = pair.get("team_slug", "unknown")
            project_slug = pair.get("project_slug")
            slack_channel = pair.get("slack_channel_id")
            discord_channel = pair.get("discord_channel_id")

            if not slack_channel or not discord_channel:
                print(f"Skipping {team_slug}: missing channel IDs")
                return

            alias = f"{team_slug}-{project_slug}-mirror" if project_slug else f"{team_slug}-mirror"
            name = f"{team_name} (Slack ↔ Discord)"

            print(f"\n=== Reconciling {team_name} ===")
            print(f"  Slack: {slack_channel}")
            print(f"  Discord: {discord_channel}")

            room_id = await self.ensure_room_exists(alias, name)
            if not room_id:
                return

            await self.invite_bot(room_id, SLACK_BOT)
            await self.invite_bot(room_id, DISCORD_BOT)
            await self.send_bridge_command(room_id, slack_channel)
            await self.send_bridge_command(room_id, discord_channel)

        async def reconcile_manifest(self, manifest_path: str):
            with open(manifest_path) as f:
                manifest = json.load(f)

            pairs = manifest.get("channel_pairs", [])
            if not pairs:
                print("No channel pairs in manifest")
                return 0

            print(f"Reconciling {len(pairs)} channel pairs...")
            for pair in pairs:
                try:
                    await self.reconcile_channel_pair(pair)
                except Exception as e:
                    print(f"Error reconciling pair: {e}")
                    import traceback
                    traceback.print_exc()

            await self.client.close()
            return 0


    async def main():
        if len(sys.argv) < 2:
            print("Usage: matrix-reconciler <manifest.json>")
            return 1
        if not os.path.exists(sys.argv[1]):
            print(f"Manifest not found: {sys.argv[1]}")
            return 1
        reconciler = MatrixReconciler()
        return await reconciler.reconcile_manifest(sys.argv[1])


    if __name__ == "__main__":
        sys.exit(asyncio.run(main()))
  '';

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.matrix-nio
    ps.aiohttp
  ]);

  webhookScript = pkgs.writeScript "matrix-reconciler-webhook" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.python3}/bin/python3 -u - "$@" <<'PY'
    import http.server
    import json
    import os
    import subprocess
    import sys
    from pathlib import Path

    MANIFEST_PATH = os.environ["MANIFEST_PATH"]
    PORT = int(os.environ.get("PORT", "9001"))


    class ManifestHandler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/manifest":
                self.send_response(404)
                self.end_headers()
                return
            try:
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length)
                manifest = json.loads(body)
                if "channel_pairs" not in manifest:
                    raise ValueError("Missing channel_pairs in manifest")

                path = Path(MANIFEST_PATH)
                path.parent.mkdir(parents=True, exist_ok=True)
                tmp = path.with_suffix(".tmp")
                tmp.write_text(json.dumps(manifest, indent=2))
                tmp.rename(path)

                subprocess.run(["systemctl", "start", "matrix-reconciler.service"], check=False)

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({"status": "ok", "pairs": len(manifest["channel_pairs"])}).encode()
                )
            except Exception as e:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode())

        def do_GET(self):
            if self.path == "/health":
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"OK")
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, fmt, *args):
            sys.stderr.write(f"{self.address_string()} - {fmt % args}\n")


    server = http.server.HTTPServer(("127.0.0.1", PORT), ManifestHandler)
    print(f"Listening on http://127.0.0.1:{PORT}", flush=True)
    server.serve_forever()
    PY
  '';
in
{
  options.scottylabs.matrix.reconciler = {
    enable = lib.mkEnableOption "Matrix bridge reconciler for governance channel pairs";

    manifestPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/matrix-reconciler/manifest.json";
      description = "Path to the channel-pair manifest JSON.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file with MATRIX_ADMIN_TOKEN and related settings.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd timer OnCalendar expression; set to \"manual\" to disable timer.";
    };

    dryRun = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Preview changes without creating rooms or sending commands.";
    };

    webhook = {
      enable = lib.mkEnableOption "HTTP webhook that accepts manifest POSTs from governance CI";

      domain = lib.mkOption {
        type = lib.types.str;
        default = "matrix-reconciler.scottylabs.org";
        description = "Public hostname for the manifest webhook.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9001;
      };
    };
  };

  config = lib.mkIf (config.scottylabs.matrix.enable && cfg.enable) {
    users.users.matrix-reconciler = {
      isSystemUser = true;
      group = "matrix-reconciler";
      home = "/var/lib/matrix-reconciler";
    };
    users.groups.matrix-reconciler = { };

    systemd.services.matrix-reconciler = {
      description = "Reconcile Matrix mirror rooms from governance manifest";
      path = [ pythonEnv ];
      script = "${reconcilerScript}/bin/matrix-reconciler ${cfg.manifestPath}";
      serviceConfig = {
        Type = "oneshot";
        User = "matrix-reconciler";
        Group = "matrix-reconciler";
        EnvironmentFile = cfg.environmentFile;
        Environment = lib.optionalString cfg.dryRun "DRY_RUN=true";
        StateDirectory = "matrix-reconciler";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ReadWritePaths = [ "/var/lib/matrix-reconciler" ];
      };
    };

    systemd.timers.matrix-reconciler = lib.mkIf (cfg.interval != "manual") {
      description = "Periodic Matrix bridge reconciliation";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
    };

    systemd.services.matrix-reconciler-webhook = lib.mkIf cfg.webhook.enable {
      description = "Webhook receiver for governance matrix-bridges manifest";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = "matrix-reconciler";
        Group = "matrix-reconciler";
        Restart = "always";
        RestartSec = "10s";
        ExecStart = webhookScript;
        Environment = "MANIFEST_PATH=${cfg.manifestPath} PORT=${toString cfg.webhook.port}";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ReadWritePaths = [ "/var/lib/matrix-reconciler" ];
      };
    };

    services.caddy.virtualHosts.${cfg.webhook.domain}.extraConfig = lib.mkIf cfg.webhook.enable ''
      reverse_proxy 127.0.0.1:${toString cfg.webhook.port}
    '';
  };
}
