# Creating Secrets

First, define the secret in [secrets.nix](../../secrets.nix). For example, to add a secret named `secret1` on `prod-02`, add this line:

```nix
"secrets/prod-02/secret1.age".publicKeys = admins ++ [ prod-02 ];
```

If the host directory does not exist, create it before continuing:

```bash
mkdir -p secrets/prod-02
```

Then, from the root of the repository (`/etc/nixos`), create the secret file:

```bash
agenix -e secrets/prod-02/secret1.age
```

This command will prompt you to enter the secret value. After entering the value, it will be encrypted and saved to the specified file, which should immediately be committed to source control.
