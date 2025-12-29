#!/usr/bin/env bash
set -e

NAME=${NAME:-}
if [ -z "$NAME" ]; then
  echo "NixOS configuration name cannot be empty."
  exit 1
fi

# Run initial nixos-anywhere setup
nix run --extra-experimental-features "nix-command flakes" \
    github:nix-community/nixos-anywhere -- \
    --flake git+https://codeberg.org/ScottyLabs/infrastructure#${NAME} root@localhost
