{
  # Keycloak login for caddy vhosts
  flake.modules.nixos.caddy-sso =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.scottylabs.caddy.sso;

      realm = "scottylabs";
      group = "/projects/devops";
      credentials = "/run/credentials/caddy.service";
      envFile = "/run/caddy/sso.env";
      envVar = name: kind: "SSO_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name)}_${kind}";

      securityBlock = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: site: ''
          oauth identity provider keycloak-${name} {
            driver generic
            realm ${realm}
            client_id ${name}
            client_secret {env.${envVar name "OIDC"}}
            scopes openid email profile
            metadata_url http://127.0.0.1:8080/realms/${realm}/.well-known/openid-configuration
            # keycloak may be stopped during caddy reloads
            delay_start 1
            retry_attempts 60
            retry_interval 2
          }

          authentication portal ${name}-portal {
            crypto default token lifetime 3600
            crypto key sign-verify {env.${envVar name "JWT"}}
            enable identity provider keycloak-${name}
            cookie domain ${site.domain}
            trust login redirect uri domain exact ${site.domain} path prefix /

            # keep the session cookie under the browser's 4 KB limit
            transform user {
              match role ${group}
              action overwrite role ${group}
            }
            transform user {
              no match role ${group}
              action overwrite role authp/guest
            }
          }

          authorization policy ${name}-policy {
            set auth url https://${site.domain}/auth/
            allow roles ${group}
            crypto key verify {env.${envVar name "JWT"}}
          }
        '') cfg.sites
      );
    in
    {
      options.scottylabs.caddy.sso.sites = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              domain = lib.mkOption {
                type = lib.types.str;
                description = "Caddy virtual host gated behind Keycloak login";
              };

              publicPaths = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Caddy path patterns served without login";
              };
            };
          }
        );
        default = { };
        description = ''
          Virtual hosts that require a /projects/devops Keycloak login, keyed by Keycloak client ID.
          OpenBao holds infra/<name>-oidc (CLIENT_SECRET) and infra/<name>-jwt (SECRET) for each.
        '';
      };

      config = lib.mkIf (cfg.sites != { }) {
        services.caddy = {
          globalConfig = ''
            order authenticate before respond
            order authorize before basicauth

            security {
            ${securityBlock}
            }
          '';

          # authorize runs before the site's own handlers
          virtualHosts = lib.mapAttrs' (
            name: site:
            lib.nameValuePair site.domain {
              extraConfig = lib.mkBefore ''
                @${name}-protected not path /auth* ${lib.concatStringsSep " " site.publicPaths}
                authorize @${name}-protected with ${name}-policy

                redir /auth/login https://${site.domain}/auth/oauth2/${realm}/ 302

                route /auth* {
                  authenticate with ${name}-portal
                }
              '';
            }
          ) cfg.sites;
        };

        systemd.services.caddy = {
          vault.infraSecrets = lib.concatMapAttrs (name: _: {
            "${name}-oidc" = {
              path = "${name}-oidc";
              key = "CLIENT_SECRET";
            };
            "${name}-jwt" = {
              path = "${name}-jwt";
              key = "SECRET";
            };
          }) cfg.sites;

          serviceConfig = {
            RuntimeDirectory = "caddy";
            RuntimeDirectoryMode = "0750";
            EnvironmentFile = [ "-${envFile}" ];
            ExecStartPre = [
              (pkgs.writeShellScript "compose-caddy-sso-env" ''
                set -eu
                umask 0077
                : > ${envFile}
                ${lib.concatStrings (
                  lib.mapAttrsToList (name: _: ''
                    if [ -s ${credentials}/${name}-oidc ] && [ -s ${credentials}/${name}-jwt ]; then
                      {
                        printf '${envVar name "OIDC"}=%s\n' "$(cat ${credentials}/${name}-oidc)"
                        printf '${envVar name "JWT"}=%s\n' "$(cat ${credentials}/${name}-jwt)"
                      } >> ${envFile}
                    fi
                  '') cfg.sites
                )}
              '')
            ];
          };

          after = [ "keycloak.service" ];
          wants = [ "keycloak.service" ];
        };
      };
    };
}
