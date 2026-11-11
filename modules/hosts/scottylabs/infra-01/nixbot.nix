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
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin" # goes to infra-02
      ];
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

          evalSystems = systems;
          buildSystems = systems;

          evalCommand = [
            (lib.getExe' inputs.iets.packages.${pkgs.stdenv.hostPlatform.system}.default "iets")
            "eval-jobs"
            "--cache-dir"
            "/var/lib/nixbot/eval-cache"
          ];
          evalWritablePaths = [ "/var/lib/nixbot/eval-cache" ];
          evalConcurrency = 16;
          # nixbuild's maxJobs
          buildConcurrency = 100;

          gitea = {
            enable = true;
            instanceUrl = "https://git.cmu.dev";
            tokenFile = "/run/systemd-vaultd/sock";
            sshPrivateKeyFile = "/run/systemd-vaultd/sock";
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

          # kennel deploys a branch once its manifest is in the binary cache
          postBuildSteps = [
            {
              name = "kennel";
              environment = { };
              # a kennel outage or a repo kennel doesn't deploy shouldn't fail the build
              warnOnly = true;
              command = [
                (lib.getExe pkgs.curl)
                "--fail-with-body"
                "--silent"
                "--show-error"
                "--header"
                (inputs.nixbot.lib.interpolate "Authorization: Bearer %(secret:kennel-nixbot-token)s")
                "--data-urlencode"
                (inputs.nixbot.lib.interpolate "project=%(prop:project)s")
                "--data-urlencode"
                (inputs.nixbot.lib.interpolate "attr=%(prop:attr)s")
                "--data-urlencode"
                (inputs.nixbot.lib.interpolate "branch=%(prop:branch)s")
                "--data-urlencode"
                (inputs.nixbot.lib.interpolate "revision=%(prop:revision)s")
                "--data-urlencode"
                (inputs.nixbot.lib.interpolate "pr_number=%(prop:pr_number)s")
                "--data-urlencode"
                (inputs.nixbot.lib.interpolate "out_path=%(prop:out_path)s")
                "https://kennel.scottylabs.org/nixbot"
              ];
            }
          ];
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
          kennel-nixbot-token = {
            path = "kennel-nixbot";
            key = "TOKEN";
          };
          gitea-ssh-key = {
            path = "nixbot-vendor-ssh";
            key = "PRIVATE_KEY";
          };
        };

        # nixbot writes its forge netrc once at startup, keep the 10d /tmp cleanup off it
        systemd.tmpfiles.rules = [ "x /tmp/systemd-private-%b-nixbot.service-*/tmp/forge-netrc-*" ];

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
            terraform.required_providers.tls.source = "hashicorp/tls";
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

            # private flake inputs are fetched over SSH
            resource.tls_private_key.nixbot_vendor.algorithm = "ED25519";

            data.forgejo_repository.vendor = {
              owner = "ScottyLabs";
              name = "infrastructure-vendor";
            };

            resource.forgejo_deploy_key.nixbot_vendor = {
              repository_id = "\${data.forgejo_repository.vendor.id}";
              title = "nixbot";
              key = "\${trimspace(tls_private_key.nixbot_vendor.public_key_openssh)}";
              read_only = true;
            };

            resource.vault_kv_secret_v2.nixbot_vendor_ssh = {
              mount = "secret";
              name = "infra/nixbot-vendor-ssh";
              data_json = "\${jsonencode({ PRIVATE_KEY = tls_private_key.nixbot_vendor.private_key_openssh })}";
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

            # Shared with kennel on deploy-01, which checks it on /nixbot
            resource.random_password.kennel_nixbot = {
              length = 64;
              special = false;
            };

            resource.vault_kv_secret_v2.kennel_nixbot = {
              mount = "secret";
              name = "infra/kennel-nixbot";
              data_json = "\${jsonencode({ TOKEN = random_password.kennel_nixbot.result })}";
            };
          }
        ];
      };
    };
}
