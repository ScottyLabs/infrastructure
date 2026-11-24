let
  users = import ./data/users.nix;

  # SSH public keys for users who can edit secrets
  admins = builtins.attrValues users;

  # SSH host keys for machines that can decrypt
  inherit (import ./data/hosts.nix) scottylabs stugov thetartan;

  all = [
    scottylabs.infra-01.ssh
    scottylabs.mac-01.ssh
    scottylabs.mac-02.ssh
    scottylabs.ci-01.ssh
    scottylabs.deploy-01.ssh
    scottylabs.signage-01.ssh
    scottylabs.snoopy.ssh
    stugov.elect-01.ssh
    thetartan.www-04.ssh
  ];
in
{
  # scottylabs-infra-01
  "secrets/scottylabs/infra-01/forgejo-signing-key.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/restic.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/pgbackrest.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/garage-backup.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/renovate-token.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/keycloak.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/vaultwarden.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/matrix-registration.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/double-puppet.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/double-puppet-env.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/garage.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/tofu-providers.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/atlantis.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/bao-role-id.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/bao-secret-id.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/cli-proxy-api.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/bridge-identity-sync.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/cloudflared-tunnel.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/snot-webhook-secret.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/typesafe-api-key.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/darwin-builder-ssh-key.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/nixbot-effects.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/harmonia-signing-key.age".publicKeys = admins ++ [
    scottylabs.infra-01.ssh
  ];
  "secrets/scottylabs/infra-01/cache-push.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];
  "secrets/scottylabs/infra-01/cache-roots.age".publicKeys = admins ++ [ scottylabs.infra-01.ssh ];

  # scottylabs-deploy-01
  "secrets/scottylabs/deploy-01/bao-role-id.age".publicKeys = admins ++ [ scottylabs.deploy-01.ssh ];
  "secrets/scottylabs/deploy-01/bao-secret-id.age".publicKeys = admins ++ [
    scottylabs.deploy-01.ssh
  ];
  "secrets/scottylabs/deploy-01/kennel.age".publicKeys = admins ++ [ scottylabs.deploy-01.ssh ];
  "secrets/scottylabs/deploy-01/kennel-webhook-secret.age".publicKeys = admins ++ [
    scottylabs.deploy-01.ssh
  ];
  "secrets/scottylabs/deploy-01/kennel-forgejo-token.age".publicKeys = admins ++ [
    scottylabs.deploy-01.ssh
  ];
  "secrets/scottylabs/deploy-01/garage.age".publicKeys = admins ++ [ scottylabs.deploy-01.ssh ];
  "secrets/scottylabs/deploy-01/cloudflared-tunnel.age".publicKeys = admins ++ [
    scottylabs.deploy-01.ssh
  ];
  "secrets/scottylabs/deploy-01/restic.age".publicKeys = admins ++ [ scottylabs.deploy-01.ssh ];
  "secrets/scottylabs/deploy-01/pgbackrest.age".publicKeys = admins ++ [ scottylabs.deploy-01.ssh ];
  "secrets/scottylabs/deploy-01/garage-backup.age".publicKeys = admins ++ [
    scottylabs.deploy-01.ssh
  ];
  "secrets/scottylabs/deploy-01/harmonia-signing-key.age".publicKeys = admins ++ [
    scottylabs.deploy-01.ssh
  ];

  # scottylabs-signage-01
  "secrets/scottylabs/signage-01/bao-role-id.age".publicKeys = admins ++ [
    scottylabs.signage-01.ssh
  ];
  "secrets/scottylabs/signage-01/bao-secret-id.age".publicKeys = admins ++ [
    scottylabs.signage-01.ssh
  ];
  "secrets/scottylabs/signage-01/harmonia-signing-key.age".publicKeys = admins ++ [
    scottylabs.signage-01.ssh
  ];

  # scottylabs-snoopy
  "secrets/scottylabs/snoopy/bao-role-id.age".publicKeys = admins ++ [ scottylabs.snoopy.ssh ];
  "secrets/scottylabs/snoopy/bao-secret-id.age".publicKeys = admins ++ [ scottylabs.snoopy.ssh ];
  "secrets/scottylabs/snoopy/harmonia-signing-key.age".publicKeys = admins ++ [
    scottylabs.snoopy.ssh
  ];

  # scottylabs-ci-01
  "secrets/scottylabs/ci-01/bao-role-id.age".publicKeys = admins ++ [ scottylabs.ci-01.ssh ];
  "secrets/scottylabs/ci-01/bao-secret-id.age".publicKeys = admins ++ [ scottylabs.ci-01.ssh ];
  "secrets/scottylabs/ci-01/forgejo-runner-token.age".publicKeys = admins ++ [ scottylabs.ci-01.ssh ];
  "secrets/scottylabs/ci-01/harmonia-signing-key.age".publicKeys = admins ++ [ scottylabs.ci-01.ssh ];

  # scottylabs-mac-01
  "secrets/scottylabs/mac-01/harmonia-signing-key.age".publicKeys = admins ++ [
    scottylabs.mac-01.ssh
  ];

  # scottylabs-mac-02
  "secrets/scottylabs/mac-02/harmonia-signing-key.age".publicKeys = admins ++ [
    scottylabs.mac-02.ssh
  ];

  # stugov-elect-01
  "secrets/stugov/elect-01/bao-role-id.age".publicKeys = admins ++ [ stugov.elect-01.ssh ];
  "secrets/stugov/elect-01/bao-secret-id.age".publicKeys = admins ++ [ stugov.elect-01.ssh ];
  "secrets/stugov/elect-01/harmonia-signing-key.age".publicKeys = admins ++ [ stugov.elect-01.ssh ];

  # thetartan-www-04
  "secrets/thetartan/www-04/bao-role-id.age".publicKeys = admins ++ [ thetartan.www-04.ssh ];
  "secrets/thetartan/www-04/bao-secret-id.age".publicKeys = admins ++ [ thetartan.www-04.ssh ];
  "secrets/thetartan/www-04/harmonia-signing-key.age".publicKeys = admins ++ [ thetartan.www-04.ssh ];

  # darwin
  "secrets/headscale-authkey.age".publicKeys = admins ++ [
    scottylabs.mac-01.ssh
    scottylabs.mac-02.ssh
  ];

  # all
  "secrets/pgadmin.age".publicKeys = admins ++ all;
  "secrets/nixbuild-ssh-key.age".publicKeys = admins ++ all;
  "secrets/falcon-sensor.age".publicKeys = admins ++ all;
}
