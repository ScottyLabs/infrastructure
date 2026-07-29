# Using Secrets

In configuration files for services managed by NixOS, first define the secret:

```nix
age.secrets.secret1 = {
  file = ../../secrets/prod-02/secret1.age;
  mode = "0400";
  owner = "secret1";
};
```

`file` should be the path to the encrypted secret file created earlier. `mode`, the file permissions, should always be set to `"0400"`. `owner` should be set to the username of the service that needs access to the secret, which may vary based on service.

Then, you can supply this file anywhere the service expects a file path, like in an `environmentFile` property:

```nix
services.secret1 = {
  enable = true;
  environmentFile = config.age.secrets.secret1.path;
};
```

Note that this requires the secret file to have first been committed to git.
