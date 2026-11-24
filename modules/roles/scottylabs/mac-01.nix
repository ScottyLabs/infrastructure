{ config, ... }:
{
  flake.modules.darwin.scottylabs-mac-01.imports = with config.flake.modules.darwin; [
    # Platform
    darwin

    # Common
    darwin-builder
    homebrew

    # Services
    scottylabs-mac-01-configuration
    scottylabs-mac-01-homebrew
  ];
}
