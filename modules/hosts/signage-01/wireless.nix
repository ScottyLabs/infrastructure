{
  flake.modules.nixos.signage-01-wireless = {
    networking.wireless = {
      enable = true;
      networks."CMU-DEVICE".authProtocols = [ "NONE" ];
    };
  };
}
