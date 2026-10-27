{ config, ... }:
{
  flake.modules.darwin.scottylabs-infra-02.imports = with config.flake.modules.darwin; [
    # Platform
    mac-mini

    # Services
    scottylabs-infra-02-builder
    scottylabs-infra-02-configuration
    scottylabs-infra-02-homebrew
  ];
}
