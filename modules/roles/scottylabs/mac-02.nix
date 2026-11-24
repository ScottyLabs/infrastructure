{ config, ... }:
{
  flake.modules.darwin.scottylabs-mac-02.imports = with config.flake.modules.darwin; [
    # Platform
    darwin

    # Common
    darwin-builder
    homebrew

    # Services
    scottylabs-mac-02-configuration
  ];
}
