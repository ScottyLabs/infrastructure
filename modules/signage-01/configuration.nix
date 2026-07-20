{
  flake.modules.nixos.signage-01-configuration =
    { lib, ... }:
    {
      networking.hostName = "signage-01";

      # Enable fonts for kiosk Firefox rendering that srvos server profile disables
      fonts.fontconfig.enable = true;

      system.stateVersion = "25.11";

      # Disable bao
      scottylabs.bao-agent.enable = lib.mkForce false;
    };
}
