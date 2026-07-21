{
  flake.modules.nixos.snoopy-configuration = {
    networking.hostName = "snoopy";

    # Computer Club VM (g:scottylabs:snoopy)
    scottylabs.publicIp = "128.237.157.156";

    system.stateVersion = "25.11";
  };
}
