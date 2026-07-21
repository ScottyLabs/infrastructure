# OpenBao Secrets

OpenBao stores secrets centrally and delivers them at runtime, complementing agenix (which encrypts secrets in git).

## When to Use What

| Use Case | Tool |
|--------------------------------------------|---------|
| Bootstrap credentials (AppRole, etc.) | agenix |
| Infrastructure secrets (ACME, Tofu tokens) | agenix |
| Runtime-provisioned secrets (OIDC clients, etc.) | OpenBao |

## Architecture

- The `openbao` and per-service terranix configurations write infra secrets to `secret/infra/*` in OpenBao
- Hosts authenticate via AppRole, and `systemd-vaultd` delivers secrets to services as systemd credentials

## For Operators

### Setting Up a New Host

After adding a host to the `hosts` list in the openbao terranix configuration (`modules/infra-01/openbao.nix`) and applying it, the AppRole is created automatically. You need to generate credentials:

1. Get the role ID (on infra-01):

```bash
set -a; . /run/agenix/tofu-providers; set +a
nix run .#openbao.init
nix run .#openbao.terraform -- output approle_role_ids
```

2. Generate a secret ID:

```bash
export BAO_ADDR=https://secrets.scottylabs.org
bao login -method=oidc
bao write -f auth/approle/role/<hostname>/secret-id # requires devops group membership
```

3. Add to `secrets.nix`:

```nix
"secrets/<hostname>/bao-role-id.age".publicKeys = admins ++ [ <hostname> ];
"secrets/<hostname>/bao-secret-id.age".publicKeys = admins ++ [ <hostname> ];
```

4. Create the agenix secrets:

```bash
agenix -e secrets/<hostname>/bao-role-id.age
agenix -e secrets/<hostname>/bao-secret-id.age
```
