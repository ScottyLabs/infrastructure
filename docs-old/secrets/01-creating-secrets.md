# Creating Secrets

Secrets are encrypted with `sops` to your SSH key, so you must have a completed user entry in [users.nix](../../users.nix), and another admin must have re-encrypted the files to it with `sops updatekeys`.

Each host's secrets live in one file, `secrets/<org>/<host>.yaml`, with one key per secret. Secrets every NixOS host reads live in `secrets/common.yaml`, and the nixbuild SSH key in `secrets/nixbuild.yaml`.

From the root of the repository, enter the devenv shell, which sets the encryption rules for these files:

```bash
devenv shell
```

To add a secret named `secret1` on `prod-02`, open the host's file and add the key:

```bash
sops secrets/scottylabs/prod-02.yaml
```

To set it without opening an editor, pass the value JSON-encoded on stdin:

```bash
printf '%s' "$value" | jq -Rs . | sops set --value-stdin secrets/scottylabs/prod-02.yaml '["secret1"]'
```

Either way the file is encrypted again when sops exits, and should immediately be committed to source control. `sops` decrypts with `~/.ssh/id_ed25519`; set `SOPS_AGE_SSH_PRIVATE_KEY_FILE` if your key lives elsewhere.
