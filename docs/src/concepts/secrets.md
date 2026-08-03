# Secrets

agenix and OpenBao each own a distinct set of secrets. agenix keeps encrypted files in the git tree and decrypts them onto a host during activation. OpenBao serves secrets over the network for a service to fetch at startup.

agenix holds bootstrap and externally-sourced secrets, such as third-party API tokens, mail and tunnel credentials, and the credentials a host uses to reach OpenBao. OpenBao holds secrets that Terraform provisions and services read at runtime, such as Keycloak OIDC client secrets and Garage S3 keys.

## agenix

`secrets.nix`, the catalog, maps each encrypted file to the public keys that may decrypt it:

```nix
"secrets/infra-01/keycloak.age".publicKeys = admins ++ [ infra-01 ];
"secrets/cloudflare-api-token.age".publicKeys = admins ++ hosts;
```

`admins` is the set of SSH keys from `users.nix`, so any admin can re-encrypt any secret. The trailing key is the host that decrypts the file. A file under `secrets/<host>/` lists that host's SSH host key, and the shared files at the top of `secrets/` add every host in the `hosts` set. A new secret needs an entry here before agenix will manage it.

A module declares `age.secrets.<name>` with the file to decrypt and its permissions. agenix decrypts it to `/run/agenix/<name>` during activation, and the module reads that path through `config.age.secrets.<name>.path`. `modules/global/acme.nix` uses the Cloudflare token this way:

```nix
age.secrets.cloudflare-api-token = {
  file = ../../secrets/cloudflare-api-token.age;
  mode = "0400";
};

security.acme.defaults.environmentFile = config.age.secrets.cloudflare-api-token.path;
```

## AppRole bootstrap

Each host stores two agenix secrets, `bao-role-id` and `bao-secret-id`, under `secrets/<host>/`. `modules/global/systemd-vaultd.nix` runs a Vault agent that reads them from `/run/agenix/` and authenticates to OpenBao with the AppRole method:

```nix
auto_auth.method = [{
  type = "approle";
  config = {
    role_id_file_path = "/run/agenix/bao-role-id";
    secret_id_file_path = "/run/agenix/bao-secret-id";
  };
}];
```

The agent connects to `http://127.0.0.1:8200` on the host that runs OpenBao and to `https://secrets.scottylabs.org` from every other host. Its token carries the `infra` policy, which grants read access to `secret/data/infra/*`. These credentials cannot come from OpenBao, since they are what lets a host reach OpenBao, so they stay in agenix.

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
