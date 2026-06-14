#!/usr/bin/env bash
# Dispatches documentation rebuild when a push changes docs/ or Excalidraw diagram files.
# Used by infra-01 Forgejo push webhook (stdin = JSON payload).

set -euo pipefail

API_BASE="${FORGEJO_API_BASE:-https://codeberg.org/api/v1}"
TARGET_REPO="${DOCS_TARGET_REPO:-ScottyLabs/documentation}"
TOKEN_FILE="${FORGEJO_TOKEN_FILE:?FORGEJO_TOKEN_FILE must be set}"

payload="$(cat)"
token="$(tr -d '\n' <"$TOKEN_FILE")"

changed_files="$(printf '%s' "$payload" | jq -r '.commits[]? | .added[], .modified[], .removed[]' 2>/dev/null || true)"

docs_changed=false
diagram_changed=false
if printf '%s\n' "$changed_files" | grep -qE '^docs/'; then
  docs_changed=true
fi
if printf '%s\n' "$changed_files" | grep -qE '(^|/)diagrams/.*\.excalidraw\.json$|scripts/generate-.*-excalidraw\.ts$'; then
  diagram_changed=true
fi

if ! docs_changed && ! diagram_changed; then
  echo "No docs/ or diagram changes in push; skipping docs dispatch"
  exit 0
fi

repo="$(printf '%s' "$payload" | jq -r '.repository.full_name // empty')"

dispatch() {
  local event_type="$1"
  echo "Dispatching ${event_type} for ${repo:-unknown repo}"
  curl -fsS -X POST \
    -H "Authorization: token ${token}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "${API_BASE}/repos/${TARGET_REPO}/dispatches" \
    -d "{\"event_type\":\"${event_type}\"}"
  echo "Documentation ${event_type} dispatch sent"
}

if docs_changed; then
  dispatch docs-updated
elif diagram_changed; then
  dispatch diagrams-updated
fi
