# Secrets

sops-nix and OpenBao each own a distinct set of secrets. sops-nix keeps encrypted files in the git tree and decrypts them onto a host when its configuration is activated. OpenBao serves secrets over the network for a service to fetch at startup.

sops-nix holds bootstrap and externally-sourced secrets, such as third-party API tokens, mail and tunnel credentials, and the credentials a host uses to reach OpenBao. OpenBao holds secrets that Terraform provisions and services read at runtime, such as Keycloak OIDC client secrets and Garage S3 keys.

We moved from agenix to sops-nix because sops-nix restarts the services that use a secret when the secret changes, and loads age plugins such as `age-plugin-tpm` ([#129](https://git.cmu.dev/ScottyLabs/infrastructure/issues/129)). OCC made the same choice in its [ADR 7](https://git.cmu.dev/ScottyLabs/occ/src/branch/main/sites/docs/src/decisions/0007-manage-secrets-with-sops-nix.md).

## sops-nix

Secrets live in YAML files under `secrets/`, one value per key, encrypted with [sops](https://github.com/getsops/sops). Each file is encrypted to a fixed set of recipients:

| File | Readable by |
| --- | --- |
| `secrets/<org>/<host>.yaml` | that host |
| `secrets/common.yaml` | every NixOS host |
| `secrets/nixbuild.yaml` | every host, including `infra-02` |

Every admin in `users.nix` can read every file. An admin decrypts with the SSH key listed there, and a host decrypts with its SSH host key, whose age public key is committed at `keys/hosts/<org>/<host>/age.pub`. `devenv.nix` builds these rules into the `SOPS_CONFIG` the devenv shell exports, so `sops` only knows them inside `devenv shell`.

A module declares `sops.secrets.<name>` next to the service that uses it. sops-nix decrypts the key of the same name from the host's own file to `/run/secrets/<name>`, and the module reads that path through `config.sops.secrets.<name>.path`. `modules/hosts/scottylabs/infra-01/keycloak/server.nix` declares one this way:

```nix
sops.secrets.keycloak.restartUnits = [ "keycloak.service" ];

systemd.services.keycloak.serviceConfig.EnvironmentFile = config.sops.secrets.keycloak.path;
```

A secret from a shared file names it with `sopsFile`, and `key` reads a key under a different name. `modules/global/acme.nix` reads the Cloudflare token from `common.yaml`, where `caddy` is `config.services.caddy.enable`:

```nix
sops.secrets.cloudflare-api-token = {
  sopsFile = ../../secrets/common.yaml;
  # Caddy reads it at startup, ACME renewals once per run
  restartUnits = lib.optional caddy "caddy.service";
  noRestartReason = lib.mkIf (!caddy) "only ACME renewals read it, once per run";
};
```

`owner`, `group` and `mode` set the decrypted file's permissions, and default to `root`, `root` and `0400`. `/run/secrets` belongs to sops-nix, which replaces the directory on every activation, so nothing else may write there. The vault agent renders its files to `/run/vault-agent/` instead.

## Restarting on change

When a deploy changes a secret, sops-nix restarts each unit in its `restartUnits` and reloads each unit in `reloadUnits`, if that unit is running. A secret that is read on each use needs neither, and says so with `noRestartReason`:

```nix
sops.secrets.renovate-token.noRestartReason = "the timer-started renovate.service loads it on each run";
```

`modules/global/sops.nix` warns about a secret that sets none of the three, and fails the build when a listed unit does not exist on the host, since sops-nix would otherwise skip it silently.

## Working with secrets

Run `sops` inside `devenv shell`. It decrypts with `~/.ssh/id_ed25519`, and `SOPS_AGE_SSH_PRIVATE_KEY_FILE` points it at a key stored elsewhere.

To edit a host's secrets in your editor:

```bash
sops secrets/scottylabs/infra-01.yaml
```

To add or replace one value without opening an editor, pass it JSON-encoded on stdin so it stays out of the process list:

```bash
printf '%s' "$value" | jq -Rs . | sops set --value-stdin secrets/scottylabs/infra-01.yaml '["renovate-token"]'
```

Then declare `sops.secrets.<name>` in the module that uses it. A key in the file but not declared anywhere is never decrypted, and a declared key missing from the file fails the build.

To add a host, commit its age public key, converted from the SSH host key:

```bash
mkdir -p keys/hosts/<org>/<host>
ssh <host> cat /etc/ssh/ssh_host_ed25519_key.pub | tee keys/hosts/<org>/<host>/ssh.pub | ssh-to-age > keys/hosts/<org>/<host>/age.pub
```

Re-enter `devenv shell` so `SOPS_CONFIG` picks up the new rule, then create the host's file and add it to the shared files:

```bash
sops secrets/<org>/<host>.yaml
sops updatekeys secrets/common.yaml
sops updatekeys secrets/nixbuild.yaml
```

Adding an admin works the same way: add their SSH key to `users.nix`, re-enter the shell, and run `sops updatekeys` on every file under `secrets/`. Removing an admin or host also needs `sops updatekeys`, and the values they could read should be rotated, since their old copies stay readable in git history.

## AppRole bootstrap

Each host's file holds two secrets, `bao-role-id` and `bao-secret-id`. `modules/global/systemd-vaultd.nix` runs a Vault agent that reads them and authenticates to OpenBao with the AppRole method:

```nix
auto_auth.method = [{
  type = "approle";
  config = {
    role_id_file_path = config.sops.secrets.bao-role-id.path;
    secret_id_file_path = config.sops.secrets.bao-secret-id.path;
  };
}];
```

The agent connects to `http://127.0.0.1:8200` on the host that runs OpenBao and to `https://secrets.scottylabs.org` from every other host. Its token carries the `infra` policy, which grants read access to `secret/data/infra/*`. These credentials cannot come from OpenBao, since they are what lets a host reach OpenBao, so they stay in sops. Changing either one restarts every Vault agent on the host.

## Runtime secrets from OpenBao

A service that needs an OpenBao secret declares it under `systemd.services.<name>.vault.infraSecrets`, keyed by credential name, with the OpenBao path and the field to read:

```nix
systemd.services.forgejo.vault.infraSecrets = {
  oidc = { path = "forgejo-oidc"; key = "CLIENT_SECRET"; };
  storage_access = { path = "forgejo-storage"; key = "MINIO_ACCESS_KEY_ID"; };
};
```

systemd-vaultd fetches `secret/data/infra/<path>` and writes each field to a systemd credential at `/run/credentials/<name>.service/<credential>`. The service reads it from that path:

```nix
environment."FORGEJO__storage__MINIO_ACCESS_KEY_ID__FILE" =
  "/run/credentials/forgejo.service/storage_access";
```

## Provisioning OpenBao

OpenBao runs on `infra-01`, stores its data in PostgreSQL, and is reached at `secrets.scottylabs.org`. Terraform provisions both its structure and its contents. The `openbao` terranix configuration defines the KV v2 mount at `secret/`, OIDC login through Keycloak, and an AppRole backend with a per-host role bound to the `infra` policy. Each service's terranix configuration writes its own runtime secrets to `secret/infra/<name>`, usually the client secret of the Keycloak OIDC client it creates alongside them. A few base values, such as the third-party identity-provider client secrets, are seeded into OpenBao by hand and read by Terraform rather than generated.

## Key types

Hosts and admins use classic keys today: SSH ed25519 for admins, and the age X25519 key that sops-nix derives from each host's SSH host key. sops encrypts a file's data key separately to each recipient, so post-quantum `age1pq1` keys and plugin identities such as `age-plugin-tpm` can be added one recipient at a time ([#64](https://git.cmu.dev/ScottyLabs/infrastructure/issues/64)). A host with a TPM-sealed identity sets `sops.age.keyFile` and `sops.age.plugins`, as OCC does in its [ADR 8](https://git.cmu.dev/ScottyLabs/occ/src/branch/main/sites/docs/src/decisions/0008-decrypt-secrets-with-a-tpm-sealed-identity.md).
