{ inputs, ... }:
{
  flake.modules.nixos.iets =
    { pkgs, ... }:

    {
      imports = [ inputs.iets.nixosModules.default ];

      iets.classic = {
        enable = true;
        nix = pkgs.lixPackageSets.stable.lix;
      };
    };

  # Upstream module is NixOS-only
  flake.modules.darwin.iets =
    { pkgs, ... }:
    let
      iets = inputs.iets.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      nix.package = inputs.iets.lib.mkClassic pkgs iets pkgs.lixPackageSets.stable.lix;
    };
}
