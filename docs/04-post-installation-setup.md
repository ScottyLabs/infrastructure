# Post-Installation Setup

Exit VMWare Remote Console, and SSH in with your user. Since the configuration has been applied, you will no longer be able to SSH in as root, and you must use your Andrew ID/Kerberos instead:

```bash
ssh -A andrewid@hostname.scottylabs.org
```

The `-A` flag is necessary for forwarding your local SSH keys to the remote server, which will be needed for Git operations. Alternatively, you can copy your local SSH public key to the server (one-time setup):

```bash
scp ~/.ssh/id_ed25519 andrewid@hostname:~/.ssh/
```

Once you're in, run `update` once, and then the initial setup script:

```bash
curl -sSL https://raw.githubusercontent.com/ScottyLabs/infrastructure/main/scripts/initial-setup.sh | bash
```

When making configuration changes, always make sure to use the `update` alias for  `sudo nixos rebuild-switch`. It creates a btrfs backup first, which you can use to roll back if something goes wrong.
