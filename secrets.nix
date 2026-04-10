let
  users = import ./users.nix;

  # SSH public keys for users who can edit secrets
  admins = builtins.attrValues (builtins.mapAttrs (_: u: u.sshPublicKey) users);

  # SSH host keys for machines that can decrypt
  infra-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaOgbg8hOVqI4zmEHODl1NJpAeImw/7z6jPnVSoXywt root@infra-01";
  deploy-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOm8p8uaXbhMbJGhkYJZWBzqYB25D9AVCUc5ACcMwU3c root@deploy-01";
  snoopy = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJxoj1W19busC7uwr4iNXlJHP3uMS7Wg3M+Kv6j0TPa root@snoopy";

  hosts = [
    infra-01
    deploy-01
    snoopy
  ];
in
{
  # infra-01
  "secrets/infra-01/codeberg-token.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/forgejo-runner-token.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/minecraft.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/keycloak.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/vaultwarden.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/matrix-registration.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/double-puppet.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/double-puppet-env.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/garage.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/tofu-garage.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/tofu-identity.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/tofu-cloudflare.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/atlantis.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/bao-role-id.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/bao-secret-id.age".publicKeys = admins ++ [ infra-01 ];

  # deploy-01
  "secrets/deploy-01/bao-role-id.age".publicKeys = admins ++ [ deploy-01 ];
  "secrets/deploy-01/bao-secret-id.age".publicKeys = admins ++ [ deploy-01 ];
  "secrets/deploy-01/kennel.age".publicKeys = admins ++ [ deploy-01 ];
  "secrets/deploy-01/kennel-webhook-secret.age".publicKeys = admins ++ [ deploy-01 ];

  # snoopy
  "secrets/snoopy/bao-role-id.age".publicKeys = admins ++ [ snoopy ];
  "secrets/snoopy/bao-secret-id.age".publicKeys = admins ++ [ snoopy ];

  # all
  "secrets/cloudflare-api-token.age".publicKeys = admins ++ hosts;
  "secrets/pgadmin.age".publicKeys = admins ++ hosts;
}
