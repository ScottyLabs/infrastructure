{
  flake.modules.nixos.deploy-01-kennel =
    { config, inputs, ... }:

    {
      imports = [
        inputs.kennel.nixosModules.default
      ];

      # Skip kennel.slice units in switch-to-configuration's failed-unit sweep
      nixpkgs.overlays = [
        (_: prev: {
          switch-to-configuration-ng = prev.switch-to-configuration-ng.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/main.rs \
                --replace-fail 'for (unit, unit_state) in new_active_units {' 'for (unit, unit_state) in new_active_units { if unit.ends_with(".service") { let slice: Result<String, _> = unit_state.proxy.get("org.freedesktop.systemd1.Service", "Slice"); if matches!(slice, Ok(s) if s == "kennel.slice") { continue; } }'
            '';
          });
        })
      ];

      age.secrets.kennel = {
        file = ../../secrets/deploy-01/kennel.age;
        owner = "kennel";
        group = "kennel";
        mode = "0440";
      };

      age.secrets.kennel-webhook-secret = {
        file = ../../secrets/deploy-01/kennel-webhook-secret.age;
        owner = "kennel";
        group = "kennel";
        mode = "0400";
      };

      age.secrets.kennel-forgejo-token = {
        file = ../../secrets/deploy-01/kennel-forgejo-token.age;
        owner = "kennel";
        group = "kennel";
        mode = "0400";
      };

      services.kennel = {
        enable = true;
        package = inputs.kennel.packages.x86_64-linux.kennel;
        devenvPackage = inputs.kennel.packages.x86_64-linux.devenv;
        webhookSecretFile = config.age.secrets.kennel-webhook-secret.path;
        environmentFile = config.age.secrets.kennel.path;
        api.port = 3001;

        # Published for ricochet's return_to allowlist (services.ricochet.allowedHostsFile)
        customDomainsFile = "/run/kennel/custom-domains";

        domains = {
          ephemeral = "scottylabs.net";
          cloudflare = {
            publicIp = "128.2.25.68";
            zones = {
              "scottylabs.org" = "ab365d7cec88f972e0b26bf59afd174f";
              "cmu.quest" = "2bf8696c7e2fdc56f9b9e98443f001cc";
              "cmu.lol" = "dbedf6cff671263c0d6f69b482895ee4";
              "cmu.courses" = "a3c2419a7e47cdc909022c5815310013";
              "cmu.dev" = "9ae67b02fb7f5a546a8fd18527115ea5";
              "cmuhousing.com" = "90331dc9edd007e59c828faa3b8d73a9";
              "cmumaps.com" = "a0686a6fe9f1e181d0c1dcdf9c293a9b";
              "cmueats.com" = "78a8413b3e73553f7def8cefe1bdc386";
              "cmugpt.com" = "dfe11e930ca4ef3d94cd9f79072315cd";
              "tartan.vote" = "97416783adc55489c6f601bbfaa48936";
              "terrier.build" = "5ec9401ebede43c78ad0167fefd3b862";
            };
          };
        };

        builder.cachix = {
          enable = true;
          cacheName = "scottylabs";
        };

        resources.postgres = {
          enable = true;
          socketDir = "/run/postgresql";
        };

        resources.valkey = {
          enable = true;
          socketPath = "/run/redis-kennel/redis.sock";
        };

        resources.garage = {
          enable = true;
          # Public S3 endpoint clients presign against
          s3Endpoint = "https://s3.kennel.scottylabs.org";
        };

        secrets = {
          enable = true;
          vaultEndpoint = "vault://secrets2.scottylabs.org/secret?auth=approle";
        };

        forgejo.apiTokenFile = config.age.secrets.kennel-forgejo-token.path;
      };

      scottylabs.postgresql.databases = [ "kennel" ];
      scottylabs.valkey.servers = [ "kennel" ];

      services.postgresql.ensureUsers = [
        {
          name = "kennel";
          ensureClauses = {
            createdb = true;
            createrole = true;
          };
        }
      ];
    };
}
