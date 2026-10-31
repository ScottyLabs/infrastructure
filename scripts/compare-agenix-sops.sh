#!/usr/bin/env bash
# One-off for #129: run as root on a host once both agenix and sops-nix decrypt its secrets.
# Checks each secret has the same contents, owner, group and mode in /run/agenix and /run/secrets.
set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  echo "needs bash 4 or newer, try: nix shell nixpkgs#bash -c bash $0" >&2
  exit 1
fi

agenix=${AGENIX_DIR:-/run/agenix}
secrets=${SECRETS_DIR:-/run/secrets}

# agenix secrets written somewhere other than /run/agenix/<name>
declare -A elsewhere=([forgejo-signing-key]=/var/lib/forgejo/.ssh/signing_ed25519)

perms() {
  if stat -c '%U:%G:%a' / >/dev/null 2>&1; then stat -L -c '%U:%G:%a' "$1"; else stat -L -f '%Su:%Sg:%Lp' "$1"; fi
}

failed=0
names=$({ ls "$agenix" 2>/dev/null || true; ls "$secrets" 2>/dev/null || true; printf '%s\n' "${!elsewhere[@]}"; } | sort -u)
for name in $names; do
  age=${elsewhere[$name]:-$agenix/$name}
  sops=$secrets/$name
  [ -e "$age" ] || [ -e "$sops" ] || continue
  if [ ! -e "$age" ] || [ ! -e "$sops" ]; then
    echo "MISSING $name (agenix: $([ -e "$age" ] && echo yes || echo no), sops: $([ -e "$sops" ] && echo yes || echo no))"
    failed=1
  elif ! cmp -s "$age" "$sops"; then
    echo "DIFF    $name: contents"
    failed=1
  elif [ "$(perms "$age")" != "$(perms "$sops")" ]; then
    echo "DIFF    $name: $(perms "$age") vs $(perms "$sops")"
    failed=1
  else
    echo "ok      $name"
  fi
done
exit "$failed"
