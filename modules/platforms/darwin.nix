{
  flake.modules.darwin.darwin = {
    nixpkgs.hostPlatform = "aarch64-darwin";

    # Headless Macs stay awake and self-recover
    power = {
      sleep.computer = "never";
      restartAfterFreeze = true;
    };
  };
}
