# Using Secrets

In configuration files for services managed by NixOS, first declare the secret, along with the units to restart when it changes:

```nix
sops.secrets.secret1 = {
  owner = "secret1";
  restartUnits = [ "secret1.service" ];
};
```

sops-nix reads the key `secret1` from the host's own file, `secrets/<org>/<host>.yaml`. Set `sopsFile` to read from a shared file such as `secrets/common.yaml`, and `key` to read a key under a different name.

The mode defaults to `"0400"`. `owner` should be set to the username of the service that needs access to the secret, which may vary based on service. A secret read on each use, which no unit needs restarting for, sets `noRestartReason` instead of `restartUnits`.

Then, you can supply its path anywhere the service expects a file path, like in an `environmentFile` property:

```nix
services.secret1 = {
  enable = true;
  environmentFile = config.sops.secrets.secret1.path;
};
```

Note that this requires the secret to have first been committed to git.
