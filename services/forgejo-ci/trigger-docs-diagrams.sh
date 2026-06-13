#!/usr/bin/env bash
# Dispatches documentation rebuild when a push includes Excalidraw diagram files.
# Used by infra-01 Forgejo push webhook (stdin = JSON payload).

set -euo pipefail

API_BASE="${FORGEJO_API_BASE:-https://codeberg.org/api/v1}"
TARGET_REPO="${DOCS_TARGET_REPO:-ScottyLabs/documentation}"
TOKEN_FILE="${FORGEJO_TOKEN_FILE:?FORGEJO_TOKEN_FILE must be set}"

payload="$(cat)"
token="$(tr -d '\n' <"$TOKEN_FILE")"

changed_files="$(printf '%s' "$payload" | jq -r '.commits[]? | .added[], .modified[], .removed[]' 2>/dev/null || true)"

if ! printf '%s\n' "$changed_files" | grep -qE '(^|/)diagrams/.*\.excalidraw\.json$|scripts/generate-.*-excalidraw\.ts$'; then
  echo "No Excalidraw diagram changes in push; skipping docs dispatch"
  exit 0
fi

repo="$(printf '%s' "$payload" | jq -r '.repository.full_name // empty')"
echo "Excalidraw changes detected in ${repo:-unknown repo}; dispatching documentation rebuild"

curl -fsS -X POST \
  -H "Authorization: token ${token}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "${API_BASE}/repos/${TARGET_REPO}/dispatches" \
  -d '{"event_type":"diagrams-updated"}'

echo "Documentation diagrams-updated dispatch sent"
