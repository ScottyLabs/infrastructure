{ config, lib, ... }:
let
  zones = import ../../../zones.nix;
  owners = [
    "admin@scottylabs.org"
    "ops@scottylabs.org"
  ];
  key = zone: lib.replaceStrings [ "." ] [ "_" ] zone;
in
{
  perSystem =
    { pkgs, ... }:
    let
      # Exchanges Atlantis's Vault token for an OpenBao identity token that Google trusts
      openbaoToken = pkgs.writeShellApplication {
        name = "openbao-google-token";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
        ];
        text = ''
          vault=http://127.0.0.1:8200/v1
          child=$(curl -sf -X POST -H "X-Vault-Token: $VAULT_TOKEN" -d '{"entity_alias":"atlantis"}' "$vault/auth/token/create/atlantis" | jq -r .auth.client_token)
          curl -sf -H "X-Vault-Token: $child" "$vault/identity/oidc/token/terranix-search-console" \
            | jq -c '{version: 1, success: true, token_type: "urn:ietf:params:oauth:token-type:jwt", id_token: .data.token, expiration_time: (now + .data.ttl | floor)}'
        '';
      };
    in
    {
      terranix.terranixConfigurations.search-console = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/search-console.tfstate";

            terraform.required_providers.google = {
              source = "hashicorp/google";
              version = "~> 7.0";
            };

            provider.google = {
              scopes = [ "https://www.googleapis.com/auth/siteverification" ];
              credentials = builtins.toJSON {
                type = "external_account";
                audience = "//iam.googleapis.com/projects/1038979353166/locations/global/workloadIdentityPools/terranix/providers/openbao";
                subject_token_type = "urn:ietf:params:oauth:token-type:jwt";
                token_url = "https://sts.googleapis.com/v1/token";
                service_account_impersonation_url = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/terranix-search-console@scottylabs-search-console.iam.gserviceaccount.com:generateAccessToken";
                credential_source.executable = {
                  command = lib.getExe openbaoToken;
                  timeout_millis = 10000;
                };
              };
            };

            data.google_site_verification_token = lib.mapAttrs' (
              zone: _:
              lib.nameValuePair (key zone) {
                type = "INET_DOMAIN";
                identifier = zone;
                verification_method = "DNS_TXT";
              }
            ) zones;

            dns = lib.mapAttrs' (
              zone: _:
              lib.nameValuePair "${zone}-search-console" {
                inherit zone;
                name = "@";
                type = "TXT";
                target = ''"''${data.google_site_verification_token.${key zone}.token}"'';
                comment = "Search Console verification";
              }
            ) zones;

            resource.google_site_verification_web_resource = lib.mapAttrs' (
              zone: _:
              lib.nameValuePair (key zone) {
                site = {
                  type = "INET_DOMAIN";
                  identifier = zone;
                };
                verification_method = "DNS_TXT";
                depends_on = [ "cloudflare_dns_record.this" ];
              }
            ) zones;

            resource.google_site_verification_owner = lib.listToAttrs (
              lib.concatMap (
                zone:
                map (
                  email:
                  lib.nameValuePair "${key zone}_${lib.head (lib.splitString "@" email)}" {
                    web_resource_id = "\${google_site_verification_web_resource.${key zone}.id}";
                    inherit email;
                  }
                ) owners
              ) (lib.attrNames zones)
            );
          }
        ];
      };
    };
}
