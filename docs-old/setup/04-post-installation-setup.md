# Post-Installation Setup

Exit VMWare Remote Console, and SSH in with your user. Since the configuration has been applied, you will no longer be able to SSH in as root, and you must use your Andrew ID/Kerberos instead:

```bash
ssh -A andrewid@hostname.scottylabs.org
```

The `-A` flag is necessary for forwarding your local SSH keys to the remote server, which will be needed for Git operations. Alternatively, you can copy your local SSH public key to the server (one-time setup):

```bash
scp ~/.ssh/id_ed25519 andrewid@hostname:~/.ssh/
```

The host can't decrypt its secrets until its SSH host key is a recipient, so add it before the first deploy. From your workstation, inside `devenv shell`, save the host key and its age conversion:

```bash
mkdir -p keys/hosts/<org>/hostname
ssh andrewid@hostname.scottylabs.org cat /etc/ssh/ssh_host_ed25519_key.pub | tee keys/hosts/<org>/hostname/ssh.pub | ssh-to-age > keys/hosts/<org>/hostname/age.pub
```

Add the host to [`hosts.nix`](../../hosts.nix) under its organization, then re-enter `devenv shell` so `sops` picks up the new recipient, and re-encrypt the shared files to it:

```bash
sops updatekeys secrets/common.yaml
sops updatekeys secrets/nixbuild.yaml
```

Every host reads its OpenBao credentials from its own file, `secrets/<org>/hostname.yaml`. Create it by following the [Setting Up a New Host](../secrets/03-openbao.md#setting-up-a-new-host) instructions, then commit everything and deploy:

```bash
colmena apply --on <org>-hostname
```

If an activation goes wrong, roll back on the host to the previous generation:

```bash
sudo nix-env --rollback -p /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

If services come up without their secrets, see [Secrets troubleshooting](../../docs/src/troubleshooting/secrets.md#a-service-starts-without-its-secret).

If this host runs garage, initialize its cluster layout once by following the [Garage](../services/garage.md) guide.
