#!/usr/bin/env bash
# One-off for #129: copies every agenix secret into the sops files byte for byte, then checks each one.
# Run from the repository root inside `devenv shell`, as an admin listed in users.nix.
# IDENTITY defaults to ~/.ssh/id_ed25519; a passphrase-protected key prompts once per file, twice per file in total.
set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  echo "needs bash 4 or newer, try: nix shell nixpkgs#bash -c bash $0" >&2
  exit 1
fi

identity=${IDENTITY:-$HOME/.ssh/id_ed25519}
: "${SOPS_CONFIG:?run this inside devenv shell, which sets SOPS_CONFIG}"
export SOPS_AGE_SSH_PRIVATE_KEY_FILE=$identity

# secrets/<org>/<host>/<name>.age -> secrets/<org>/<host>.yaml, shared files by who reads them
target() {
  case $1 in
    secrets/cloudflare-api-token.age | secrets/pgadmin.age) echo secrets/common.yaml ;;
    secrets/nixbuild-ssh-key.age) echo secrets/nixbuild.yaml ;;
    secrets/*/*/*.age) echo "$(dirname "$1").yaml" ;;
    *)
      echo "no sops file for $1" >&2
      exit 1
      ;;
  esac
}

b64() { base64 | tr -d '\n'; }

declare -A docs originals
mapfile -t files < <(git ls-files 'secrets/*.age')

for file in "${files[@]}"; do
  out=$(target "$file")
  if [ -e "$out" ]; then
    echo "$out already exists, remove it to start over" >&2
    exit 1
  fi
  originals[$file]=$(age -d -i "$identity" "$file" | b64)
  docs[$out]=$(printf '%s' "${originals[$file]}" | base64 -d | jq -Rs --arg key "$(basename "$file" .age)" --argjson doc "${docs[$out]:-"{}"}" '$doc + {($key): .}')
done

for out in "${!docs[@]}"; do
  printf '%s' "${docs[$out]}" | jq -S . | sops encrypt --filename-override "$out" --input-type json --output-type yaml >"$out"
  echo "wrote $out"
done

failed=0
for file in "${files[@]}"; do
  key=$(basename "$file" .age)
  if [ "$(sops decrypt --extract "[\"$key\"]" "$(target "$file")" | b64)" = "${originals[$file]}" ]; then
    echo "ok   $file"
  else
    echo "DIFF $file"
    failed=1
  fi
done

[ "$failed" = 0 ] && echo "all ${#files[@]} secrets match"
exit "$failed"
