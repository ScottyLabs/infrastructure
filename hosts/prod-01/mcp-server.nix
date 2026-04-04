{ mcp-server, ... }:

{
  imports = [
    mcp-server.nixosModules.default
  ];

  scottylabs.bao-agent = {
    enable = true;
    secrets.mcp-server = {
      project = "mcp-server";
      user = "mcp-server";
    };
  };

  services.mcp-server = {
    enable = true;
    environmentFile = "/run/secrets/mcp-server.env";
  };

  systemd.services.mcp-server = {
    after = [ "bao-agent.service" ];
    wants = [ "bao-agent.service" ];
  };
<<<<<<< HEAD
}
=======
}
>>>>>>> deploy-01-setup
