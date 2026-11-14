{ config, ... }:
{
  flake.modules.darwin.scottylabs-infra-04.imports = with config.flake.modules.darwin; [
    # Platform
    darwin

    # Common
    darwin-builder
    homebrew

    # Services
    scottylabs-infra-04-configuration
  ];
}
