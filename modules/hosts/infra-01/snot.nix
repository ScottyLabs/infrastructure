{ config, ... }:
{
  flake.modules.nixos.infra-01-snot =
    {
      config,
      lib,
      inputs,
      ...
    }:

    {
      imports = [ inputs.snot.nixosModules.default ];

      services.snot = {
        enable = true;
        environmentFiles = [ config.age.secrets.snot-webhook-secret.path ];
        settings = {
          hostname = "knot.cmu.dev";
          listen_addr = "127.0.0.1:5555";
          owner_did = "did:plc:fvrytycduivujsvng7t4ihgk";
          plc_url = "https://plc.directory";
          push_remote = "git@git.cmu.dev";
          users."did:plc:fvrytycduivujsvng7t4ihgk" = "scottylabs";
        };
      };

      age.secrets.snot-webhook-secret.file = ../../../secrets/infra-01/snot-webhook-secret.age;

      # Read-only DB access, snot connects as its DynamicUser over the socket
      services.postgresql.ensureUsers = [ { name = "snot"; } ];
      systemd.services.postgresql-setup.postStart = lib.mkAfter ''
        psql --port=${toString config.services.postgresql.settings.port} -d forgejo -c "
          GRANT CONNECT ON DATABASE forgejo TO snot;
          GRANT USAGE ON SCHEMA public TO snot;
          GRANT SELECT ON ALL TABLES IN SCHEMA public TO snot;
          ALTER DEFAULT PRIVILEGES FOR ROLE forgejo IN SCHEMA public GRANT SELECT ON TABLES TO snot;
        "
      '';

      services.caddy.virtualHosts."knot.cmu.dev".extraConfig = ''
        reverse_proxy 127.0.0.1:5555
      '';
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.snot = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/snot.tfstate";

            # Direct because cloudflared can't carry the knot eventstream
            dns.knot = {
              zone = "cmu.dev";
              host = "infra-01";
              comment = "snot knot";
            };
          }
        ];
      };
    };
}
