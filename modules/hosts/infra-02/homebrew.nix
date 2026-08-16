{
  flake.modules.darwin.infra-02-homebrew = {
    nix-homebrew = {
      enable = true;
      user = "scottylabs";
    };

    homebrew = {
      enable = true;
      onActivation.cleanup = "zap";

      # BlueBubbles bridges iMessage into Matrix
      casks = [ "bluebubbles" ];
    };
  };
}
