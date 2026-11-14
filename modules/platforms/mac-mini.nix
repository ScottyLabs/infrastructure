{
  flake.modules.darwin.mac-mini = {
    nixpkgs.hostPlatform = "aarch64-darwin";

    # Headless mini stays awake and self-recovers
    # Also used by vmapple hosts, which ignore restart parameters
    power = {
      sleep.computer = "never";
      restartAfterPowerFailure = true;
      restartAfterFreeze = true;
    };
  };
}
