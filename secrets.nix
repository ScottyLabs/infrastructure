let
  users = import ./users.nix;

  # SSH public keys for users who can edit secrets
  admins = builtins.attrValues users;

  # SSH host keys for machines that can decrypt
  scottylabs-infra-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaOgbg8hOVqI4zmEHODl1NJpAeImw/7z6jPnVSoXywt root@infra-01";
  scottylabs-deploy-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOm8p8uaXbhMbJGhkYJZWBzqYB25D9AVCUc5ACcMwU3c root@deploy-01";
  scottylabs-signage-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHY/TsQztMS7l5ozBhLu05O+ze/DasZ3+grn5tvapoGX root@signage-01";
  scottylabs-snoopy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJxoj1W19busC7uwr4iNXlJHP3uMS7Wg3M+Kv6j0TPa root@snoopy";
  scottylabs-infra-03 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOaQliYDA6EKA9xrJiWqk+unJ4Tm80dbu674zXpFVIxL root@infra-03";

  hosts = [
    scottylabs-infra-01
    scottylabs-infra-03
    scottylabs-deploy-01
    scottylabs-signage-01
    scottylabs-snoopy
  ];
in
{
  # scottylabs-infra-01
  "secrets/scottylabs/infra-01/forgejo-signing-key.age".publicKeys = admins ++ [
    scottylabs-infra-01
  ];
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
  "secrets/scottylabs/infra-01/nixbuild-ssh-key.age".publicKeys = admins ++ [ scottylabs-infra-01 ];
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
  "secrets/stugov/elect-01/bao-role-id.age".publicKeys = admins;
  "secrets/stugov/elect-01/bao-secret-id.age".publicKeys = admins;

  # all
  "secrets/cloudflare-api-token.age".publicKeys = admins ++ hosts;
  "secrets/pgadmin.age".publicKeys = admins ++ hosts;
}
