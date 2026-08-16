{ config, ... }:
{
  flake.modules.darwin.infra-02.imports = with config.flake.modules.darwin; [
    # Platform
    mac-mini

    # Services
    infra-02-configuration
    infra-02-homebrew
  ];
}
