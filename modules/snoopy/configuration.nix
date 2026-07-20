{
  flake.modules.nixos.snoopy-configuration = {
    networking.hostName = "snoopy";

    system.stateVersion = "25.11";
  };
}
