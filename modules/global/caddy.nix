{
  flake.modules.nixos.caddy = {
    services.caddy.globalConfig = ''
      metrics
    '';
  };
}
