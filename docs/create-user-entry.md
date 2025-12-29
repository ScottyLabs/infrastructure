# Create a User Entry

To create a user entry, add a new attribute to the `users` set in [users.nix](../users.nix). The attribute name should be your Andrew ID. Each user entry should include the following fields:

- `git.name`: Your full name for Git commits.
- `git.email`: Your email address for Git commits.
- `sshPublicKey`: Your SSH public key.

## Getting Your SSH Public Key

If you don't have an SSH key, generate one:

```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

Then copy your public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the output and add it to the `sshPublicKey` field in your user entry. Make sure to add it as a signing key on [Codeberg](https://codeberg.org/user/settings/keys) (and optionally [GitHub](https://github.com/settings/keys)) so commits show as `Verified`.
