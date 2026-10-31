# Secrets

How secrets are stored and declared is in [Secrets](../concepts/secrets.md). Everything below runs inside `devenv shell` unless it is marked as running on a host.

## A service starts without its secret

sops-nix decrypts every secret in `sops-install-secrets.service`, and the "Secrets failed to install" alert fires when it fails. On the host:

```bash
sudo journalctl -u sops-install-secrets -b --no-pager | tail -50
```

`Error getting data key: 0 successful groups required, got 0` means the host is not a recipient of that file. Usually its key was added to `keys/hosts/` without running `sops updatekeys` on the file afterwards, or the host was reinstalled and has a new SSH host key. Compare the host's key with the committed one:

```bash
ssh <host> cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
cat keys/hosts/<org>/<host>/age.pub
```

If they differ, commit the new `age.pub` and `ssh.pub`, re-enter `devenv shell`, run `sops updatekeys` on the host's file, `secrets/common.yaml` and `secrets/nixbuild.yaml`, and deploy.

## A service kept its old secret after a deploy

sops-nix restarts the units in a secret's `restartUnits` only when the decrypted value changed, and only if they were running. The journal lists what it changed:

```bash
sudo journalctl -u sops-install-secrets -b --no-pager | grep -E 'adding|modifying|removing'
```

If the secret shows up as modified but the service was not restarted, its `sops.secrets.<name>` declaration is missing the unit in `restartUnits`. Add it, and restart the service by hand this once. If the secret does not show up at all, the deploy did not include the new value: check that the change to `secrets/` is committed on the branch you deployed.

For example, rotating the Keycloak admin password means updating `tofu-providers` too, which restarts Atlantis on deploy so it plans with the new password. To run tofu by hand on `infra-01` with the same values, load them into a root shell:

```bash
sudo -i
set -a; . /run/secrets/tofu-providers; set +a
```

## A file under /run/secrets disappears

sops-nix replaces `/run/secrets` on every activation and removes anything it did not write there. Render other files somewhere else, such as `/run/vault-agent/` for the vault agent's templates.

## sops says there is no matching creation rule

`sops` reads its rules from `SOPS_CONFIG`, which only `devenv shell` sets. Run it inside the shell, and re-enter the shell after changing `keys/`, `hosts.nix` or `users.nix` so the rules are rebuilt. A new file has to match one of the paths in [Secrets](../concepts/secrets.md#sops-nix), such as `secrets/<org>/<host>.yaml`.

## You cannot decrypt a file

`sops` decrypts with `~/.ssh/id_ed25519`. If your key lives elsewhere, point `SOPS_AGE_SSH_PRIVATE_KEY_FILE` at it. If it still fails with `0 successful groups required, got 0`, your key is not a recipient of the file yet: another admin runs `sops updatekeys` on it after your key is in `users.nix`.

## The build fails on a secret

`sops.secrets.<name> restarts or reloads <unit>, which this host does not define` means a unit in `restartUnits` or `reloadUnits` is misspelled or does not run on that host. Use the name `systemctl list-units` shows, including the `.service` suffix.

A failing `manifest.json` build that names a key means the key is declared in a module but missing from the sops file it reads. Add it with `sops`, or fix `key` or `sopsFile` in the declaration.

A warning that a secret `restarts nothing when it changes` means it sets none of `restartUnits`, `reloadUnits` and `noRestartReason`. Add the unit that reads it, or a `noRestartReason` if it is read on each use.

## A sops file has a merge conflict

A sops file cannot be merged by hand, because its `mac` covers every value and a hand-merged file fails with `MAC mismatch`. Take one side whole, then apply the other side's changes again with `sops`:

```bash
git checkout --theirs secrets/scottylabs/infra-01.yaml
sops secrets/scottylabs/infra-01.yaml
```
