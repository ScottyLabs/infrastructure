let
  users = import ./users.nix;

  # SSH public keys for users who can edit secrets
  admins = builtins.attrValues (builtins.mapAttrs (_: u: u.sshPublicKey) users);

  # SSH host keys for machines that can decrypt
  infra-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaOgbg8hOVqI4zmEHODl1NJpAeImw/7z6jPnVSoXywt root@infra-01";
  prod-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOm8p8uaXbhMbJGhkYJZWBzqYB25D9AVCUc5ACcMwU3c root@prod-01";
  prod-02 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYYPbjYn0jjTb50znqzhPc0Dl8EdImBzy97Mm+vOlz0 root@prod-02";

  hosts = [ infra-01 prod-01 prod-02 ];
in
{
  "secrets/infra-01/minecraft.age".publicKeys = admins ++ [ infra-01 ];
  "secrets/infra-01/keycloak.age".publicKeys = admins ++ [ infra-01 ];

  "secrets/prod-01/dalmatian.age".publicKeys = admins ++ [ prod-01 ];

  "secrets/acme-credentials.age".publicKeys = admins ++ hosts;
}
