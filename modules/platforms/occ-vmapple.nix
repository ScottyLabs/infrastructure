{
  flake.modules.darwin.occ-vmapple = {
    nixpkgs.hostPlatform = "aarch64-darwin";

    power.sleep.computer = "never";
  };
}
