# OpenBao Secrets

OpenBao provides self-service secret management for project teams. Unlike agenix (which encrypts secrets in git), OpenBao stores secrets centrally and delivers them to hosts at runtime.

## When to Use What

| Use Case                                   | Tool    |
|--------------------------------------------|---------|
| Bootstrap credentials (AppRole, etc.)      | agenix  |
| Infrastructure secrets (ACME, Tofu tokens) | agenix  |
| Project/application secrets                | OpenBao |

## Architecture

- Developers log in via Keycloak OIDC to manage secrets
- Hosts authenticate via AppRole auth to fetch secrets at runtime
- `bao-agent` runs on each host and renders secrets to `/run/secrets/<name>.env`

## For Developers

### Accessing OpenBao

```bash
export BAO_ADDR=https://secrets2.scottylabs.org
bao login -method=oidc
```

Your access depends on your Keycloak group membership:
- `/projects/<project>` → read/write `secret/projects/<project>/dev/*`
- `/projects/<project>/admins` → read/write `secret/projects/<project>/prod/*`
- `/projects/devops` → full admin access

### Managing Secrets

```bash
# Write secrets
bao kv put secret/projects/my-project/prod/env \
  DATABASE_URL="postgres://..." \
  API_KEY="..."

# Read secrets
bao kv get secret/projects/my-project/prod/env

# List secrets
bao kv list secret/projects/my-project/prod
```

## For Operators

### Setting Up a New Host

After adding a host to `hosts` in `flake.nix` and deploying, the AppRole is created automatically. You need to generate credentials:

1. Get the role ID (on infra-01 after tofu-identity runs):

```bash
sudo journalctl -u tofu-identity | grep '"<hostname>"' | tail -1
```

2. Generate a secret ID:

```bash
export BAO_ADDR=https://secrets2.scottylabs.org
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

### Adding a Project to a Host

In the host's service config:

```nix
scottylabs.bao-agent = {
  enable = true;
  secrets.<service-name> = {
    project = "<project-name>";
    user = "<service-user>";
  };
};

services.<service-name> = {
  enable = true;
  environmentFile = "/run/secrets/<service-name>.env";
};

systemd.services.<service-name> = {
  after = [ "bao-agent.service" ];
  wants = [ "bao-agent.service" ];
};
```

The host automatically gets read access to `secret/projects/<project>/prod/*`.

### Adding a New Project

1. (temporary) Add to `tofu/identity/projects.json`:

```json
["discord-verify", "new-project"]
```

2. Push and wait for `tofu-identity` to apply

3. (temporary) Add users to the Keycloak group `/projects/new-project` (or `/projects/new-project/admins` for prod access)
