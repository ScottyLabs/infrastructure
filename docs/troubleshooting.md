---
title: "Troubleshooting"
project: "infrastructure"
projectType: "starlight"
repo: "https://codeberg.org/scottylabs/infrastructure"
---
## comin not deploying after a force push

If someone force pushes to the repository, comin's cached repo and state can get out of sync with the remote. Symptoms include comin fetching successfully but never triggering a build.

To fix:

```bash
sudo systemctl stop comin
sudo rm -rf /var/lib/comin/repository
sudo rm /var/lib/comin/store.json
sudo systemctl start comin
```

Wait ~30 seconds, then verify:

```bash
comin status
```

You should see a new build being evaluated or deployed.

## ACME first-deploy race when adding a new subdomain

When a new subdomain is added to `tofu/cloudflare/records.tf` and a corresponding nginx vhost with `enableACME = true; forceSSL = true;` is added in the same comin reconcile, the first ACME issuance attempt typically fails. Let's Encrypt's resolvers query authoritative DNS faster than the new Cloudflare record propagates, so HTTP-01 validation hits NXDOMAIN.

Symptoms from outside the cluster:

- `curl https://<subdomain>` fails TLS verification with `curl: (60) SSL certificate problem` and `ssl_verify_result: 19` ("self-signed certificate in certificate chain").
- HTTP-to-HTTPS redirect still works, and `dig +short <subdomain>` returns the right IP.

The clue is `acme-order-renew-<subdomain>.service`, not `acme-<subdomain>.service`. The base `acme-<subdomain>.service` always succeeds because it only generates a `minica` self-signed placeholder so nginx can start. The real Let's Encrypt order runs in `acme-order-renew-<subdomain>.service`, and that is what fails on first deploy. Check the journal:

```bash
sudo journalctl -u acme-order-renew-<subdomain>.service -n 50 --no-pager
```

A failed run looks like:

```
urn:ietf:params:acme:error:dns :: DNS problem: NXDOMAIN looking up A for <subdomain>
```

To fix, first verify DNS is now resolvable from outside Cloudflare:

```bash
dig +short <subdomain> @1.1.1.1
```

Then manually re-run the order and reload nginx to pick up the issued cert:

```bash
sudo systemctl start acme-order-renew-<subdomain>.service
sudo systemctl reload nginx
```

Re-check the journal afterwards to confirm `Server responded with a certificate.` and `Installing new certificate`. The `acme-renew-<subdomain>.timer` would also self-heal on its own schedule, but manual retry is faster.

A definitive fix would be switching to a DNS-based ACME challenge (DNS-01 via the Cloudflare API), since that bypasses the public-DNS-propagation dependency. We have intentionally not made that change because we plan to adopt [dns-persist-01](https://letsencrypt.org/2026/02/18/dns-persist-01.html) once it ships, and do not want a one-time DNS-01 migration in between.

## Enabling website mode on a bucket

The [henrywhitaker3/garage](https://registry.terraform.io/providers/henrywhitaker3/garage) Terraform provider does not expose bucket website configuration. The AWS provider could in principle call `PutBucketWebsite` against garage's S3 API, but its credentials would need to come from a garage access key declared in the same terraform module, and Terraform evaluates provider configuration before any resources exist. When a new garage bucket needs to be served anonymously via the `s3_web` listener (e.g., `scottylabs-assets`), the website flag must therefore be set once manually against garage's admin API.

After `tofu-garage.service` has created the bucket on infra-01, run these on the host. Set `RESOURCE` to the terraform resource name for the bucket (the suffix after `garage_bucket.` in the `.tf` file, e.g. `scottylabs_assets`):

```bash
RESOURCE=scottylabs_assets
```

Read the admin token from the agenix-decrypted env file that terraform itself uses:

```bash
TOKEN=$(sudo grep '^TF_VAR_garage_admin_token=' /run/agenix/tofu-garage | cut -d= -f2-)
```

Look up the bucket ID from terraform state:

```bash
BUCKET_ID=$(sudo tofu -chdir=/var/lib/tofu-garage state show "garage_bucket.$RESOURCE" | awk '$1 == "id" {print $3}' | tr -d '"')
```

Call the admin API:

```bash
curl -fsSL -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"websiteAccess":{"enabled":true,"indexDocument":"index.html"}}' \
  "http://127.0.0.1:3903/v2/UpdateBucket?id=$BUCKET_ID"
```

The setting persists across garage restarts. Recreating the bucket through terraform would clear it; in that case, re-run this command.

For **`scottylabs-docs`**, also set a custom error document so missing pages return the Starlight 404 page instead of raw S3 XML:

```bash
curl -fsSL -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"websiteAccess":{"enabled":true,"indexDocument":"index.html","errorDocument":"404.html"}}' \
  "http://127.0.0.1:3903/v2/UpdateBucket?id=$BUCKET_ID"
```

Nested doc URLs like `/tartan-vote/contributing/` require **Caddy rewrites** on `docs.scottylabs.org` (see `hosts/infra-01/garage.nix`) because Garage's web endpoint does not always resolve directory paths to `index.html`. After changing that vhost, reload caddy on infra-01.

## `tofu-cloudflare` fails with Cloudflare 81054 (CNAME already exists)

OpenTofu manages **A** records in `tofu/cloudflare/records.tf`. Cloudflare returns error `81054` when an **A** record is created for a hostname that already has a **CNAME** (or another conflicting record).

This often happens when OpenTofu tries to create an **A** record but Cloudflare already has a **CNAME** on that name. On scottylabs.org, **`@` and `www` are Railway CNAMEs** and must not be in `local.a_records` (see `records.tf`).

**Find the failing hostname:**

```bash
cd /var/lib/tofu-cloudflare
tofu init -input=false
tofu plan
```

**Fix:**

1. In the [Cloudflare DNS dashboard](https://dash.cloudflare.com), delete the conflicting record for that hostname (commonly `matrix-reconciler` on `scottylabs.org`), **or**
2. If you want to keep a CNAME, do not manage that name in `records.tf`.

Then re-run apply:

```bash
sudo systemctl start tofu-cloudflare.service
```

Or redeploy with comin. A failed `tofu-cloudflare` oneshot during switch causes the whole NixOS activation to roll back even when Matrix bridges started.

## `alloy.service` fails on boot

Grafana Alloy ships journald logs to Loki. A bad River config (for example `relabel_rules = ""` on `loki.source.journal`) makes the process exit immediately.

```bash
journalctl -u alloy -n 50 --no-pager
```

Fix is in `common/alloy.nix` (`relabel_rules = loki.relabel.journal.rules`). Alloy failures do not block Matrix bridging but do fail the deploy if `alloy` is enabled on that host.

## `@slack` bridge appears offline or stops responding

Element often shows bridge bots with a **grey offline dot** even when they work. Send `help` in the DM — if the bot replies, it is up.

### 1. Check the service on infra-01

```bash
systemctl status mautrix-slack
journalctl -u mautrix-slack -n 80 --no-pager
```

Look for:

- `the supplied account key is invalid` — E2EE pickle key mismatch (common after deploys)
- `Homeserver -> bridge connection is not working` — Synapse cannot reach the appservice URL
- `ForeignTablesFound` / database errors — Postgres issue

Restart after fixing config:

```bash
sudo systemctl restart mautrix-slack
```

### 2. Pickle key must be stable across deploys

Nix regenerates `/var/lib/mautrix-slack/config.yaml` on config changes. If `encryption.pickle_key` is set to `generate` in Nix, each deploy can overwrite the key and break the bridge DB.

`mautrix-slack.nix` expects a stable key in the agenix env file:

```bash
# On infra-01, read the key the bridge already generated (if service ever worked):
sudo yq '.encryption.pickle_key' /var/lib/mautrix-slack/config.yaml

# Or generate a new one:
head -c 32 /dev/urandom | base64
```

Add to `secrets/infra-01/double-puppet-env.age` (same file as `DOUBLE_PUPPET_SECRET`; see [`double-puppet-env.example`](https://codeberg.org/scottylabs/infrastructure/src/branch/main/secrets/infra-01/double-puppet-env.example)):

```bash
ENCRYPTION_PICKLE_KEY=<paste key here>
```

Re-encrypt with agenix, redeploy, then restart `mautrix-slack`. If you generated a **new** key instead of copying the existing one, you may need to reset the bridge DB (`sudo systemctl stop mautrix-slack`, drop/recreate `mautrix-slack` postgres db, restart) and re-run Slack `login token`.

### 3. Login-level “offline” vs bot offline

`list-logins` can show **BAD_CREDENTIALS** for one Slack account while the bot still responds. That only affects messages sent as that login — run `logout <login ID>` and `login token` again, or use relay mode.

### 4. Synapse not delivering events to the bridge

If the bot accepts invites but never replies, grep Synapse for failed appservice transactions:

```bash
journalctl -u matrix-synapse -n 200 --no-pager | rg transactions
```

Regenerate registration if tokens drifted:

```bash
sudo systemctl restart mautrix-slack-registration matrix-synapse mautrix-slack
```

### `!slack bridge` fails with insufficient permissions for `m.bridge`

When plumbing Slack into an existing mautrix-discord portal room, `@slack` must be able to send `m.bridge` state events. Discord portal rooms default `@slack` to power level 0, which is below the room's `m.bridge` threshold.

**Manual fix** (in the Discord portal room, e.g. `#discord_1461933322505818156` for DevOps):

1. Room settings → Permissions → set `@slack:doggylabs.org` to at least **50** (or promote to admin).
2. Re-run `!slack bridge <slack-channel-id>`.

Bridge admins can also pass `--ignore-permissions` to skip the pre-check:

```text
!slack bridge <SLACK_APP_LOGIN_ID> T03EVH29W-C08K3Q77ZQF --ignore-permissions --overwrite
!slack set-relay <SLACK_APP_LOGIN_ID>
```

(`synapse_mautrix_slack_link` / OpenTofu Apply runs these automatically when `MATRIX_SLACK_RELAY_LOGIN_ID` is set; team ID comes from `data/org.toml` → `local.matrix_slack_team_id`.)

`synapse_mautrix_slack_link` (terraform-provider-synapse) promotes `@slack` via the Synapse admin API before sending the bridge command; rebuild/redeploy the provider if you hit this during OpenTofu apply.

### Discord → Slack: “Your message was not bridged: You're not logged in”

mautrix-slack only sends a Matrix user's messages to Slack when that user has run `login token` in the `@slack` management room — unless **relay mode** is on. Discord-originated messages appear as `@discord_…:doggylabs.org` puppets, which do not have Slack logins.

ScottyLabs enables relay on infra-01 (`bridges.slack.relay.enable` + `default_relays` from `SLACK_RELAY_LOGIN_ID` in `double-puppet-env.age`). OpenTofu / `synapse_mautrix_slack_link` runs `!slack bridge <relay-login> <team>-<channel>`, `!slack set-relay`, and `!discord set-relay --create mautrix` when `matrix_slack_relay_login_id` is set.

**Immediate fix** in the Discord portal room (DevOps example):

```text
!slack set-relay <SLACK_APP_LOGIN_ID>
```

Use the login ID from `list-logins` after `login app` (see below). The legacy user-token login (`T03EVH29W-U0A7HGVMPB6` / ops+slack) relays text but **cannot** set per-message Slack avatars.

**After deploy**: restart `mautrix-slack`, then re-run `set-relay` in already-plumbed portal rooms (or re-apply `synapse_mautrix_slack_link`). Generate portal commands:

```bash
./infrastructure/scripts/portal-relay-commands.sh "$SLACK_RELAY_LOGIN_ID"
```

Optional: team members can still run `login token` in `@slack` to post to Slack under their own Slack identity instead of through the relay.

### Slack app relay setup (Discord → Slack names + avatars)

Per-message Slack avatars require a **Slack app** relay (`login app`), not a user session (`login token`). User-token relay (e.g. ops+slack) can show names in the message body or via limited customize support, but the supported path for avatar mirroring is app + `chat:write.customize` + `public_media`.

**1. Create the Slack app** (Slack workspace admin, one-time):

- Manifest: [`infrastructure/services/matrix/slack-app-manifest.yaml`](https://codeberg.org/scottylabs/infrastructure/src/branch/main/services/matrix/slack-app-manifest.yaml) (includes `chat:write.customize`).
- Create app → install to workspace `scottylabs` → note **bot token** (`xoxb-`) and **app token** (`xapp-`, socket mode).
- **Invite the app bot** to every bridged Slack channel (DevOps `C08K3Q77ZQF`, hub `C096TM8EMS8`, quest, cmu-courses, etc.).

**2. Register on the bridge** (dedicated Matrix account, DM `@slack:doggylabs.org`):

```text
login app
list-logins
```

Copy the new app login ID. Optionally `logout <old-user-login-id>` after cutover.

**3. Store secrets** — edit `secrets/infra-01/double-puppet-env.age` (template: [`double-puppet-env.example`](https://codeberg.org/scottylabs/infrastructure/src/branch/main/secrets/infra-01/double-puppet-env.example)):

```bash
PUBLIC_MEDIA_SIGNING_KEY=<head -c 32 /dev/urandom | base64>
AVATAR_PROXY_KEY=<head -c 32 /dev/urandom | base64>
SLACK_RELAY_LOGIN_ID=<app login ID from list-logins>
```

Re-encrypt with agenix, redeploy infra (comin), then set the same relay ID for OpenTofu:

```bash
export TF_VAR_matrix_slack_relay_login_id="$SLACK_RELAY_LOGIN_ID"
# or MATRIX_SLACK_RELAY_LOGIN_ID for the terraform-provider-synapse
```

**4. Per-portal relay** — in each `#discord_<channel_id>` portal room:

```text
!slack set-relay <SLACK_APP_LOGIN_ID>
!discord set-relay --create mautrix
```

### Ping messages (Discord ↔ Slack)

Members with **both Slack and Discord linked in Keycloak** get real cross-platform @mentions when `bridge-identity-map.json` is deployed (`/etc/mautrix-bridge/identity-map.json`). Everyone else still gets **`[display name]`** labels so random Matrix ghosts do not ping wrong accounts.

Regenerate the map after IdP link changes (requires `KEYCLOAK_CLIENT_ID` / `KEYCLOAK_CLIENT_SECRET`):

```bash
cd governance
cargo build -p governance
./target/debug/governance --data-dir data generate-bridge-identity-map
```

Requires `KEYCLOAK_CLIENT_ID` and `KEYCLOAK_CLIENT_SECRET` in the environment (same credentials used for OpenTofu `resolve-identity`).

| Direction | Linked in Keycloak | Not linked |
|-----------|-------------------|------------|
| **Discord → Slack** | Matrix `@discord_…` mention → Slack `<@U…>` via `mautrix-slack-bridge-identity-pings.patch` | `[Alice]` label (`mautrix-slack-relay-outbound.patch`) |
| **Slack → Discord** | Matrix `@slack_…` mention → Discord `<@id>` + `allowed_mentions` | `[Alice]` label (`mautrix-discord-ping-prefix.patch`) |

`@room` / `@everyone` / `@here` still become `[@room]` on the other side.

### Markdown (Discord ↔ Slack)

**Discord → Slack**: Discord markdown becomes Matrix HTML in the Discord bridge; the ScottyLabs mautrix-slack patch sets `PerMessageProfileRelay` so relay mode does not flatten messages through `message_formats` (which would strip formatting). Outbound relay posts use Slack rich text blocks (bold, italic, strikethrough, inline code, links).

**Slack → Discord**: Slack mrkdwn becomes Matrix HTML in mautrix-slack; mautrix-discord converts HTML back to Discord markdown on webhook relay sends. Rich-text block messages (not just plain mrkdwn) generally format better.

### Discord replies vs threads on Slack

Discord **channel replies** (reply to a message, not a thread channel) and **new threads** both show up in Slack as thread replies. The mautrix-slack patch tells them apart via Matrix relations:

| Discord action | Matrix relation | Slack behavior |
|----------------|-----------------|----------------|
| Reply to a message | `m.in_reply_to` only | Thread under the parent **and** “also send to channel” (`reply_broadcast`) |
| Thread message / new thread | `m.thread` | Thread only (no channel broadcast) |

After deploy, test: reply in the main channel should appear in the Slack thread and in the main channel; post inside a Discord thread should stay thread-only on Slack.

### Profile pictures (Discord ↔ Slack)

**Discord → Slack** (relay): mautrix-slack posts with per-message username and avatar when relay uses a **Slack app** login, `public_media.enabled` is true, and `appservice.public_address` points at the Matrix client domain. Discord attaches avatars on `com.beeper.per_message_profile` (same as names); ScottyLabs patches mautrix-slack to use that for Slack `icon_url`. GIF/link embeds (Tenor, etc.) are relayed as the original HTTPS URL so Slack can unfurl them — not as opaque “sent an image” text. Caddy on `matrix.<domain>` must proxy `/_mautrix/publicmedia/*` to the slack appservice (port 29335) with **`handle`** (not `handle_path` — the bridge serves the full path).

**Slack → Discord**: Matrix Slack ghosts carry avatars; Discord only shows them on webhook relay sends. In each plumbed portal room:

```text
!discord set-relay --create mautrix
```

**Matrix → Discord (Slack messages stuck in the portal room):** mautrix-discord only forwards Matrix messages from users without a Discord bridge login when the portal has a **relay webhook** (`RelayWebhookID`). Without it, `handleMatrixMessage` drops the event as “user not logged in”. Symptom: Slack → Matrix and Discord → Slack work, but nothing reaches Discord.

1. Confirm the portal has a relay webhook: in the portal room, `!discord set-relay --create mautrix` should reply with “Saved webhook …”. If it says “requires you to be logged in”, no bridge user has an active Discord session — run `login token` or `login qr` in `@discord` as any account that can manage webhooks in that channel, then re-run set-relay.
2. OpenTofu / `synapse_mautrix_slack_link` sends the same command automatically; it needs at least one logged-in mautrix-discord user on the server (ScottyLabs patch `mautrix-discord-set-relay-automation.patch` lets `--create` use any logged-in bridge user, not only the command sender).
3. Check logs: `journalctl -u mautrix-discord -n 100 --no-pager | rg -i 'not logged in|Ignoring|relay'`.

(`enable_webhook_avatars` and `bridge.public_address` must be set — see `mautrix-discord.nix`. Caddy must proxy `/mautrix-discord/*` to the discord appservice on port 29334 with **`handle`**, not `handle_path`.)

Add stable keys to `secrets/infra-01/double-puppet-env.age` (see [`double-puppet-env.example`](https://codeberg.org/scottylabs/infrastructure/src/branch/main/secrets/infra-01/double-puppet-env.example)), then re-encrypt and redeploy:

```bash
PUBLIC_MEDIA_SIGNING_KEY=<random base64>
AVATAR_PROXY_KEY=<random base64>
SLACK_RELAY_LOGIN_ID=<app login ID>
```

If you change `AVATAR_PROXY_KEY` after Discord was already using signed avatar URLs, restart `mautrix-discord` and re-run `!discord set-relay --create` in plumbed rooms if avatars break.

**Post-deploy verification on infra-01:**

```bash
./infrastructure/scripts/verify-bridge-avatars.sh
```

Optional member-state check (Slack ghost must have `avatar_url` for Discord webhook PFP):

```bash
export MATRIX_ADMIN_TOKEN='syt_...'
export ROOM='!RnECHhwspQhQkekSAm:doggylabs.org'   # DevOps portal
export GHOST='@slack_t03evh29w-u09e6eha5r8:doggylabs.org'
./infrastructure/scripts/verify-bridge-avatars.sh
```

Do **not** validate avatars from the static Discord **APP profile card** for the webhook bot — only the **message line** avatar matters.

**Thread test:** send a plain Slack message first, then a thread reply. Thread bridging needs the relay-threads patch in the running `mautrix-discord` binary and at least one Discord bridge login in the portal room.
