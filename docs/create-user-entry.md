# Create a User Entry

To create a user entry, add a new attribute to the `users` set in [users/default.nix](../../users/default.nix). The attribute name should be your Andrew ID. Each user entry should include the following fields:

- `git.name`: Your full name for Git commits.
- `git.email`: Your email address for Git commits.
- `sshPublicKey`: Your SSH public key.
- `gpgFingerprint`: Your GPG key fingerprint.
- `gpgPublicKeyFile`: Path to your GPG public key file.

## Getting Your SSH Public Key

If you don't have an SSH key, generate one:

```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

Then copy your public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the output and add it to the `sshPublicKey` field in your user entry.

## Getting Your GPG Fingerprint and Public Key

Check if you already have a GPG key:

```bash
gpg --list-secret-keys --keyid-format=long
```

If not, generate one:

```bash
gpg --full-generate-key
```

Choose ECC (sign and encrypt), Curve 25519, and set an expiration of your choice. The output will look like:

```bash
sec   ed25519/ABCD1234EFGH5678 2025-01-15 [SC]
      1234 5678 9ABC DEF0 1234  5678 ABCD 1234 EFGH 5678
uid                 [ultimate] Your Name <your@email.com>
```

Your fingerprint is the part after the algorithm (e.g., `ABCD1234EFGH5678`). Export your public key to `users/keys/`:

```bash
gpg --armor --export ABCD1234EFGH5678 > users/keys/andrewid.asc
```

Finally, add your GPG public key to [GitHub](https://github.com/settings/keys) so commits show as "Verified".
