let
  users = import ./data/users.nix;

  # SSH public keys for users who can edit secrets
  admins = builtins.attrValues users;

  # SSH host keys for machines that can decrypt
  inherit (import ./data/hosts.nix)
    scottylabs-infra-01
    scottylabs-infra-02
    scottylabs-infra-03
    scottylabs-deploy-01
    scottylabs-signage-01
    scottylabs-snoopy
    stugov-elect-01
    thetartan-www-04
    ;

  all = [
    scottylabs-infra-01
    scottylabs-infra-02
    scottylabs-infra-03
    scottylabs-deploy-01
    scottylabs-signage-01
    scottylabs-snoopy
    stugov-elect-01
    thetartan-www-04
  ];
in
{
  # scottylabs-infra-01
  "secrets/scottylabs/infra-01/forgejo-signing-key.age".publicKeys = admins ++ [
    scottylabs-infra-01
  ];
  "secrets/scottylabs/infra-01/restic.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/pgbackrest.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/garage-backup.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/renovate-token.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/keycloak.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/vaultwarden.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/matrix-registration.age".publicKeys = admins ++ [
    scottylabs-infra-01
  ];
  "secrets/scottylabs/infra-01/double-puppet.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/double-puppet-env.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/garage.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/tofu-providers.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/atlantis.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/bao-role-id.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/bao-secret-id.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/cli-proxy-api.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/bridge-identity-sync.age".publicKeys = admins ++ [
    scottylabs-infra-01
  ];
  "secrets/scottylabs/infra-01/cmu-vpn-password.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/cmu-vpn-passkey.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/cloudflared-tunnel.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/snot-webhook-secret.age".publicKeys = admins ++ [
    scottylabs-infra-01
  ];
  "secrets/scottylabs/infra-01/typesafe-api-key.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
  "secrets/scottylabs/infra-01/nixbot-cachix-token.age".publicKeys = admins ++ [
    scottylabs-infra-01
  ];
  "secrets/scottylabs/infra-01/infra-02-builder-ssh-key.age".publicKeys = admins ++ [
    scottylabs-infra-01
  ];

  # scottylabs-deploy-01
  "secrets/scottylabs/deploy-01/bao-role-id.age".publicKeys = admins ++ [ scottylabs-deploy-01 ];
  "secrets/scottylabs/deploy-01/bao-secret-id.age".publicKeys = admins ++ [ scottylabs-deploy-01 ];
  "secrets/scottylabs/deploy-01/kennel.age".publicKeys = admins ++ [ scottylabs-deploy-01 ];
  "secrets/scottylabs/deploy-01/kennel-webhook-secret.age".publicKeys = admins ++ [
    scottylabs-deploy-01
  ];
  "secrets/scottylabs/deploy-01/kennel-forgejo-token.age".publicKeys = admins ++ [
    scottylabs-deploy-01
  ];
  "secrets/scottylabs/deploy-01/garage.age".publicKeys = admins ++ [ scottylabs-deploy-01 ];
  "secrets/scottylabs/deploy-01/cloudflared-tunnel.age".publicKeys = admins ++ [
    scottylabs-deploy-01
  ];
  "secrets/scottylabs/deploy-01/restic.age".publicKeys = admins ++ [ scottylabs-deploy-01 ];
  "secrets/scottylabs/deploy-01/pgbackrest.age".publicKeys = admins ++ [ scottylabs-deploy-01 ];
  "secrets/scottylabs/deploy-01/garage-backup.age".publicKeys = admins ++ [ scottylabs-deploy-01 ];

  # scottylabs-signage-01
  "secrets/scottylabs/signage-01/bao-role-id.age".publicKeys = admins ++ [ scottylabs-signage-01 ];
  "secrets/scottylabs/signage-01/bao-secret-id.age".publicKeys = admins ++ [ scottylabs-signage-01 ];

  # scottylabs-snoopy
  "secrets/scottylabs/snoopy/bao-role-id.age".publicKeys = admins ++ [ scottylabs-snoopy ];
  "secrets/scottylabs/snoopy/bao-secret-id.age".publicKeys = admins ++ [ scottylabs-snoopy ];

  # scottylabs-infra-03
  "secrets/scottylabs/infra-03/bao-role-id.age".publicKeys = admins ++ [ scottylabs-infra-03 ];
  "secrets/scottylabs/infra-03/bao-secret-id.age".publicKeys = admins ++ [ scottylabs-infra-03 ];
  "secrets/scottylabs/infra-03/forgejo-runner-token.age".publicKeys = admins ++ [
    scottylabs-infra-03
  ];

  # stugov-elect-01
  "secrets/stugov/elect-01/bao-role-id.age".publicKeys = admins ++ [ stugov-elect-01 ];
  "secrets/stugov/elect-01/bao-secret-id.age".publicKeys = admins ++ [ stugov-elect-01 ];

  # thetartan-www-04
  "secrets/thetartan/www-04/bao-role-id.age".publicKeys = admins ++ [ thetartan-www-04 ];
  "secrets/thetartan/www-04/bao-secret-id.age".publicKeys = admins ++ [ thetartan-www-04 ];

  # all
  "secrets/pgadmin.age".publicKeys = admins ++ all;
  "secrets/nixbuild-ssh-key.age".publicKeys = admins ++ all;
}
