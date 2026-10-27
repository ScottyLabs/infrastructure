{
  config,
  inputs,
  lib,
  ...
}:
{
  flake.modules.nixos.scottylabs-infra-01-nixbot =
    {
      config,
      lib,
      pkgs,
      users,
      ...
    }:

    let
      domain = "nixbot.scottylabs.org";
      inherit (config.services.nixbot) port;

      # nixbot runs flake prefetch-inputs through the passthru Nix, which Lix lacks
      ietsEvalJobs =
        pkgs.runCommand "nix-eval-jobs-iets" { passthru.nix = pkgs.nixVersions.nixComponents_2_35.nix-cli; }
          ''
            mkdir -p $out/bin
            ln -s ${
              lib.getExe' inputs.iets.packages.${pkgs.stdenv.hostPlatform.system}.default "iets"
            } $out/bin/nix-eval-jobs
          '';
    in
    {
      imports = [ inputs.nixbot.nixosModules.nixbot ];

      config = {
        age.secrets.nixbot-cachix-token = {
          file = ../../../../secrets/scottylabs/infra-01/nixbot-cachix-token.age;
          mode = "0400";
        };

        services.nixbot = {
          enable = true;
          inherit domain;
          nginx.enable = false;
          useHTTPS = true;

          # nixbot names OIDC users oidc:<issuer without https://>:<username>
          admins = map (name: "oidc:idp.scottylabs.org/realms/scottylabs:${name}") (builtins.attrNames users);

          evalSystems = [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
          ];

          packages.nix-eval-jobs = ietsEvalJobs;

          gitea = {
            enable = true;
            instanceUrl = "https://git.cmu.dev";
            tokenFile = "/run/systemd-vaultd/sock";
            userAllowlist = [ "ScottyLabs" ];
            topic = "nixbot";
          };

          oidc = {
            enable = true;
            name = "ScottyLabs";
            discoveryUrl = "https://idp.scottylabs.org/realms/scottylabs/.well-known/openid-configuration";
            clientId = "nixbot";
            clientSecretFile = "/run/systemd-vaultd/sock";
            # Match admins by Andrew ID instead of Keycloak's user UUID
            mapping.username = "preferred_username";
          };

          cachix = {
            enable = true;
            name = "scottylabs";
            auth.authToken.file = config.age.secrets.nixbot-cachix-token.path;
          };

          # main and PRs are always built
          branches = {
            staging = {
              matchGlob = "staging";
              registerGCRoots = false;
            };
            dev = {
              matchGlob = "dev";
              registerGCRoots = false;
            };
          };
        };

        systemd.services.nixbot.vault.infraSecrets = {
          gitea-token = {
            path = "nixbot-forgejo";
            key = "TOKEN";
          };
          oidc-client-secret = {
            path = "nixbot-oidc";
            key = "CLIENT_SECRET";
          };
        };

        services.caddy.virtualHosts.${domain}.extraConfig = ''
          reverse_proxy 127.0.0.1:${toString port}
        '';
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.nixbot = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/nixbot.tfstate";

            dns.nixbot = {
              name = "nixbot";
              tunnel = "scottylabs-infra-01";
              comment = "Nix CI";
            };

            terraform.required_providers.forgejo = {
              source = "svalabs/forgejo";
              version = "~> 1.0";
            };
            provider.forgejo = [
              {
                host = "\${var.forgejo_url}";
                api_token = "\${var.forgejo_token}";
              }
              # Forgejo creates tokens only over basic auth
              {
                alias = "nixbot";
                host = "\${var.forgejo_url}";
                username = "\${forgejo_user.nixbot.login}";
                password = "\${random_password.nixbot_forgejo.result}";
              }
            ];
            variable.forgejo_url = {
              type = "string";
              default = "https://git.cmu.dev";
            };
            variable.forgejo_token.sensitive = true;

            resource.random_password.nixbot_forgejo = {
              length = 64;
              special = false;
            };

            resource.forgejo_user.nixbot = {
              login = "nixbot";
              full_name = "nixbot";
              email = "ops+nixbot@scottylabs.org";
              password = "\${random_password.nixbot_forgejo.result}";
              must_change_password = false;
            };

            resource.forgejo_personal_access_token.nixbot = {
              provider = "forgejo.nixbot";
              user = "\${forgejo_user.nixbot.login}";
              name = "nixbot";
              scopes = [
                "write:repository"
                "write:issue"
                "read:user"
              ];
            };

            # nixbot needs repo admin to manage its webhooks
            resource.forgejo_team.nixbot = {
              organization = "ScottyLabs";
              name = "nixbot";
              description = "nixbot CI";
              permission = "admin";
              includes_all_repositories = true;
              can_create_org_repo = false;
              units_map = lib.genAttrs [
                "repo.actions"
                "repo.code"
                "repo.ext_issues"
                "repo.ext_wiki"
                "repo.issues"
                "repo.packages"
                "repo.projects"
                "repo.pulls"
                "repo.releases"
                "repo.wiki"
              ] (_: "admin");
            };

            resource.forgejo_team_member.nixbot = {
              team_id = "\${forgejo_team.nixbot.id}";
              user = "\${forgejo_user.nixbot.login}";
            };

            resource.vault_kv_secret_v2.nixbot_forgejo = {
              mount = "secret";
              name = "infra/nixbot-forgejo";
              data_json = "\${jsonencode({ TOKEN = forgejo_personal_access_token.nixbot.token })}";
            };

            resource.keycloak_openid_client.nixbot = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "nixbot";
              name = "nixbot";
              enabled = true;
              access_type = "CONFIDENTIAL";
              standard_flow_enabled = true;
              direct_access_grants_enabled = false;
              valid_redirect_uris = [ "https://nixbot.scottylabs.org/auth/oidc/callback" ];
            };

            resource.vault_kv_secret_v2.nixbot_oidc = {
              mount = "secret";
              name = "infra/nixbot-oidc";
              data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.nixbot.client_secret })}";
            };
          }
        ];
      };
    };
}
