{
  config,
  lib,
  pkgs,
  ...
}:

let
  cmuSubnets = import ./subnets.nix;

  # TODO: use flake input once nix supports sha256 repos
  umvpnSrc = fetchTarball {
    url = "https://codeberg.org/ScottyLabs/umvpn/archive/0a2eba6d928f862140598f03e874b4cb12cf1d58d6d9c066d2ee97de9bff398a.tar.gz";
    sha256 = "sha256-hakHXfzLQjJ4W9HIwb9t9SnNC9wZByU6MYPT/fERs9U=";
  };
in
{
  imports = [ (umvpnSrc + "/nix/module.nix") ];

  age.secrets = {
    cmu-vpn-password.file = ../../../secrets/infra-01/cmu-vpn-password.age;
    cmu-vpn-passkey.file = ../../../secrets/infra-01/cmu-vpn-passkey.age;
  };

  services.umvpn = {
    enable = true;
    package = pkgs.callPackage (umvpnSrc + "/nix/package.nix") { };
    group = "Campus VPN";
    username = "scottylabs-svc";
    passwordFile = config.age.secrets.cmu-vpn-password.path;
    privateKeyFile = config.age.secrets.cmu-vpn-passkey.path;
    gateway.enable = true;
  };

  services.tailscale.extraUpFlags = [
    "--advertise-routes=${lib.concatStringsSep "," cmuSubnets}"
  ];

  scottylabs.tailnet.headscale.autoApproveRoutes = cmuSubnets;
}
