#!/usr/bin/env bash
set -e

# Ask for the nixos configuration name
read -p "Enter the name of the NixOS configuration to deploy: " NAME
if [ -z "$NAME" ]; then
  echo "NixOS configuration name cannot be empty."
  exit 1
fi

# Run initial nixos-anywhere setup
nix run --extra-experimental-features "nix-command flakes" \
    github:nix-community/nixos-anywhere -- \
    --flake github:ScottyLabs/infrastructure#${NAME} root@localhost
