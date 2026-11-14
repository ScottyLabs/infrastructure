{
  # Homebrew owned by nix-darwin; anything not declared is removed on activation
  flake.modules.darwin.homebrew =
    { config, ... }:

    {
      nix-homebrew = {
        enable = true;
        user = config.system.primaryUser;
      };

      homebrew = {
        enable = true;
        onActivation.cleanup = "zap";
      };
    };
}
