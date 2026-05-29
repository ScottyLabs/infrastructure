#!/usr/bin/env bash
# Print Matrix bridge relay commands for each plumbed Discord portal (from governance/tofu).
# Usage: ./portal-relay-commands.sh [SLACK_APP_LOGIN_ID]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TF_JSON="$ROOT/governance/tofu/matrix_bridges.tf.json"
SLACK_RELAY="${1:-${SLACK_RELAY_LOGIN_ID:-${MATRIX_SLACK_RELAY_LOGIN_ID:-}}}"

if [[ ! -f "$TF_JSON" ]]; then
  echo "Missing $TF_JSON" >&2
  exit 1
fi

echo "# In each Discord portal room (#discord_<channel_id>), run if relays drift after deploy:"
echo "# (OpenTofu Apply / synapse_mautrix_slack_link already runs these on create/update.)"
echo

jq -r '.resource.synapse_mautrix_slack_link | to_entries[] |
  "# \(.value.team_name)\(if .value.project_name then " / \(.value.project_name)" else "" end) — Discord \(.value.discord_channel_id) ↔ Slack \(.value.slack_channel_id)
!discord set-relay --create mautrix
\(if $relay != "" then "!slack set-relay \($relay)" else "# !slack set-relay <SLACK_APP_LOGIN_ID>  # from list-logins after login app" end)
"' --arg relay "$SLACK_RELAY" "$TF_JSON"

echo
echo "# Slack app setup (once, in DM with @slack:doggylabs.org on a dedicated Matrix account):"
echo "#   login app   # paste bot (xoxb-) and app (xapp-) tokens"
echo "#   list-logins # copy app login ID into double-puppet-env.age as SLACK_RELAY_LOGIN_ID"
echo "# Invite the Slack app bot to each bridged Slack channel above."
