{
  flake.modules.nixos.infra-01-cmu-vpn =
    {
      config,
      pkgs,
      ...
    }:

    let
      # TODO: use flake input once nix supports sha256 repos
      umvpnSrc = fetchTarball {
        url = "https://codeberg.org/ScottyLabs/umvpn/archive/eef7188f6f9da52f350d2ad534d62bd0231cf344faf44493bfb750d777df4ecf.tar.gz";
        sha256 = "sha256-V5SH2H9AxrmxhcjavFVuHtHPIPuVixhSDxWrZPiwfLM=";
      };
    in
    {
      imports = [ (umvpnSrc + "/nix/module.nix") ];

      age.secrets = {
        cmu-vpn-password.file = ../../../../secrets/infra-01/cmu-vpn-password.age;
        cmu-vpn-passkey.file = ../../../../secrets/infra-01/cmu-vpn-passkey.age;
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
    };
}
