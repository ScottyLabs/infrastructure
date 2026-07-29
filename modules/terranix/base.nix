{ inputs, lib, ... }:
let
  # Per-host tunnel IDs from scottylabs.cloudflared.tunnelId
  tunnelIds = lib.filterAttrs (_: id: id != null) (
    lib.mapAttrs (
      _: host: host.config.scottylabs.cloudflared.tunnelId or null
    ) inputs.self.nixosConfigurations
  );

  tunnelIdFor =
    record: host:
    tunnelIds.${host} or (throw "dns.${record}: host ${host} has no scottylabs.cloudflared.tunnelId");
in
{
  flake.modules.terranix.base =
    { lib, config, ... }:
    {
      options.dns = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              zone = lib.mkOption {
                type = lib.types.str;
                default = "scottylabs.org";
              };
              host = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Serving host; renders a CNAME to <host>.scottylabs.org.";
              };
              tunnel = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Host whose Cloudflare Tunnel serves this record";
              };
              target = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Verbatim record content (A address or external CNAME target).";
              };
              type = lib.mkOption {
                type = lib.types.str;
                default = "CNAME";
              };
              proxied = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              comment = lib.mkOption { type = lib.types.str; };
            };
          }
        );
        default = { };
        description = "DNS records to provision (record name -> entry).";
      };

      config = {
        terraform.required_providers = {
          cloudflare = {
            source = "cloudflare/cloudflare";
            version = "~> 5.0";
          };
          keycloak = {
            source = "keycloak/keycloak";
            version = "~> 5.0";
          };
          vault = {
            source = "hashicorp/vault";
            version = "~> 5.0";
          };
          garage = {
            source = "registry.terraform.io/jkossis/garage";
            version = "~> 1.0";
          };
          random = {
            source = "hashicorp/random";
            version = "~> 3.0";
          };
        };

        variable = {
          cloudflare_api_token.sensitive = true;
          keycloak_admin_user.sensitive = true;
          keycloak_admin_password.sensitive = true;
          garage_admin_token.sensitive = true;
        };

        provider = {
          cloudflare.api_token = "\${var.cloudflare_api_token}";
          keycloak = {
            client_id = "admin-cli";
            username = "\${var.keycloak_admin_user}";
            password = "\${var.keycloak_admin_password}";
            url = "https://idp.scottylabs.org";
          };
          vault.address = "http://127.0.0.1:8200";
          garage = {
            endpoint = "http://127.0.0.1:3903";
            token = "\${var.garage_admin_token}";
          };
        };

        data = {
          cloudflare_zones.all = { };
          keycloak_realm.scottylabs.realm = "scottylabs";
        };

        locals = lib.mkIf (config.dns != { }) {
          zone_ids = "\${{ for z in data.cloudflare_zones.all.result : z.name => z.id }}";
        };

        resource.cloudflare_dns_record.this = lib.mkIf (config.dns != { }) {
          for_each = lib.mapAttrs (
            name: e:
            assert lib.assertMsg (
              lib.count (v: v != null) [
                e.host
                e.target
                e.tunnel
              ] == 1
            ) "dns.${name}: exactly one of host, target, or tunnel must be set";
            {
              inherit (e) zone type comment;
              # Tunnel CNAMEs only resolve through the Cloudflare proxy
              proxied = e.proxied || e.tunnel != null;
              content =
                if e.host != null then
                  "${e.host}.scottylabs.org"
                else if e.tunnel != null then
                  "${tunnelIdFor name e.tunnel}.cfargotunnel.com"
                else
                  e.target;
            }
          ) config.dns;
          zone_id = "\${local.zone_ids[each.value.zone]}";
          name = "\${each.key}";
          content = "\${each.value.content}";
          type = "\${each.value.type}";
          ttl = 1;
          proxied = "\${each.value.proxied}";
          comment = "\${each.value.comment} - managed by terranix";
        };
      };
    };

  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      terranix.exportDevShells = false;

      packages.atlantis-yaml = pkgs.writeText "atlantis.yaml" (
        builtins.toJSON {
          version = 3;
          parallel_plan = true;
          parallel_apply = true;
          projects = lib.mapAttrsToList (name: _: {
            inherit name;
            dir = ".";
            workspace = name;
            autoplan.when_modified = [
              "modules/**"
              "flake.nix"
              "flake.lock"
            ];
          }) (lib.removeAttrs config.terranix.terranixConfigurations [ "garage" ]);
        }
      );
    };

  flake.modules.nixos.infra-01-tofu-providers = {
    age.secrets.tofu-providers = {
      file = ../../secrets/infra-01/tofu-providers.age;
      mode = "0400";
    };
  };
}
