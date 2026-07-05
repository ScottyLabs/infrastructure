#!/usr/bin/env bash
set -euo pipefail
name="${1:?}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
read -r owner rel <<<"$(nix eval --raw --impure --expr "
  let
    cfg = builtins.fromTOML (builtins.readFile ./.forgejo/pinned-forks.toml);
    r = builtins.head (builtins.filter (x: x.name == \"${name}\") cfg.repos);
  in r.owner + \"\t\" + r.to_update
")"
file="$root/$rel"
rev="$(curl -fsSL "https://api.github.com/repos/${owner}/${name}/commits/main" | jq -r .sha)"
grep -q "$rev" "$file" && exit 0
url="https://github.com/${owner}/${name}/archive/${rev}.tar.gz"
err="$(nix eval --raw --impure --expr "(builtins.fetchTarball { url = \"$url\"; sha256 = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"; }).outPath" 2>&1)" || true
got="$(sed -n 's/.*got: *\(sha256:[^ ]*\).*/\1/p' <<<"$err")"
sri="$(nix hash convert --hash-algo sha256 --to sri "$got")"
tmp="$(mktemp)"
sed -e "s/^\([[:space:]]*rev = \)\"[^\"]*\"/\1\"${rev}\"/" \
    -e "s/^\([[:space:]]*hash = \)\"[^\"]*\"/\1\"${sri}\"/" "$file" >"$tmp"
mv "$tmp" "$file"
