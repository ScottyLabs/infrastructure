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
    url = "https://codeberg.org/ScottyLabs/umvpn/archive/3ee390c4a7168666a2df9372ea31cfff97c38be1a6c0a8ba1deb3514311fd680.tar.gz";
    sha256 = "sha256-egU20jACiczvf+9feAUIRnKx8EPyzM26s8nz5palw9k=";
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
