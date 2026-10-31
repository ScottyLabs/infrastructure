# OpenBao Secrets

OpenBao stores secrets centrally and delivers them at runtime, complementing sops-nix (which encrypts secrets in git).

## When to Use What

| Use Case | Tool |
|--------------------------------------------|---------|
| Bootstrap credentials (AppRole, etc.) | sops-nix |
| Infrastructure secrets (ACME, Tofu tokens) | sops-nix |
| Runtime-provisioned secrets (OIDC clients, etc.) | OpenBao |

## Architecture

- The `openbao` and per-service terranix configurations write infra secrets to `secret/infra/*` in OpenBao
- Hosts authenticate via AppRole, and `systemd-vaultd` delivers secrets to services as systemd credentials

## For Operators

### Setting Up a New Host

After adding a host to the `hosts` list in the openbao terranix configuration (`modules/hosts/infra-01/openbao.nix`) and applying it, the AppRole is created automatically. You need to generate credentials:

1. Get the role ID (on infra-01):

```bash
set -a; . /run/secrets/tofu-providers; set +a
nix run .#openbao.init
nix run .#openbao.terraform -- output approle_role_ids
```

2. Generate a secret ID:

```bash
export BAO_ADDR=https://secrets.scottylabs.org
bao login -method=oidc
bao write -f auth/approle/role/<hostname>/secret-id # requires devops group membership
```

3. Add both to the host's sops file, inside `devenv shell` (the host's key must already be in `keys/hosts/`, see [Post-Installation Setup](../setup/04-post-installation-setup.md)):

```bash
printf '%s' "$role_id" | jq -Rs . | sops set --value-stdin secrets/<org>/<hostname>.yaml '["bao-role-id"]'
printf '%s' "$secret_id" | jq -Rs . | sops set --value-stdin secrets/<org>/<hostname>.yaml '["bao-secret-id"]'
```

`modules/global/systemd-vaultd.nix` already declares both on every host, and restarts the host's Vault agents when either changes.
