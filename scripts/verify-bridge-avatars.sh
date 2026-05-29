#!/usr/bin/env bash
# Smoke-test public avatar proxy routes on the Matrix client domain.
# Run on infra-01 after deploy, or from anywhere with network access to matrix.<domain>.
set -euo pipefail

MATRIX_DOMAIN="${MATRIX_DOMAIN:-matrix.doggylabs.org}"
BASE="https://${MATRIX_DOMAIN}"

probe() {
  local path=$1
  curl -sS -D - -o /tmp/bridge-avatar-probe-body "${BASE}${path}" | tr -d '\r'
}

echo "Checking Caddy routes on ${BASE} (expect bridge error text, not Synapse JSON)..."

slack_headers=$(probe "/_mautrix/publicmedia/doggylabs.org/invalid/invalid")
discord_headers=$(probe "/mautrix-discord/avatar/doggylabs.org/invalid/invalid")

slack_code=$(echo "${slack_headers}" | awk '/^HTTP/ {print $2; exit}')
discord_code=$(echo "${discord_headers}" | awk '/^HTTP/ {print $2; exit}')
slack_body=$(cat /tmp/bridge-avatar-probe-body)

echo "  GET /_mautrix/publicmedia/... -> HTTP ${slack_code}"
echo "  GET /mautrix-discord/avatar/... -> HTTP ${discord_code}"

if echo "${slack_body}" | grep -q '"errcode"'; then
  echo "FAIL: /_mautrix/publicmedia/* is still routed to Synapse."
  exit 1
fi

discord_body=$(curl -sS "${BASE}/mautrix-discord/avatar/doggylabs.org/invalid/invalid")
if echo "${discord_body}" | grep -q '"errcode"'; then
  echo "FAIL: /mautrix-discord/* is still routed to Synapse."
  exit 1
fi

echo "OK: requests reach bridge appservices (not Synapse)."

if [[ -n "${MATRIX_ADMIN_TOKEN:-}" && -n "${ROOM:-}" && -n "${GHOST:-}" ]]; then
  echo "Checking ${GHOST} avatar_url in ${ROOM}..."
  room_enc=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "${ROOM}")
  ghost_enc=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "${GHOST}")
  avatar_url=$(curl -sS \
    -H "Authorization: Bearer ${MATRIX_ADMIN_TOKEN}" \
    "${BASE}/_matrix/client/v3/rooms/${room_enc}/state/m.room.member/${ghost_enc}" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("avatar_url",""))')
  if [[ -z "${avatar_url}" ]]; then
    echo "WARN: ghost has no avatar_url in room member state."
  else
    echo "  avatar_url=${avatar_url}"
  fi
fi

rm -f /tmp/bridge-avatar-probe-body
