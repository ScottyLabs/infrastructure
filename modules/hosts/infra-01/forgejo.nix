{ config, ... }:
{
  flake.modules.nixos.infra-01-forgejo =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (config.services.forgejo) stateDir;
      signingKeyPriv = "${stateDir}/.ssh/signing_ed25519";
      signingKeyPub = "${signingKeyPriv}.pub";
      signingPubKey = pkgs.writeText "forgejo-signing.pub" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHIq2XYZ218T07NQbBXLCT8H+h3GVv/tqS63dnMBjCdp cmu.dev commit signing";
    in
    {
      services.forgejo = {
        enable = true;
        lfs.enable = true;
        dump.enable = true;

        database = {
          type = "postgres";
          createDatabase = false;
          socket = "/run/postgresql";
          name = "forgejo";
          user = "forgejo";
        };

        settings = {
          DEFAULT.APP_NAME = "cmu.dev";

          server = {
            DOMAIN = "git.cmu.dev";
            ROOT_URL = "https://git.cmu.dev/";
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = 3002;
            # git SSH over the host sshd on port 22
            SSH_PORT = 22;
            SSH_DOMAIN = "git.cmu.dev";
          };

          repository = {
            DEFAULT_BRANCH = "main";
            DEFAULT_PRIVATE = "public";
            DEFAULT_PUSH_CREATE_PRIVATE = false;
            ENABLE_PUSH_CREATE_USER = true;
            ENABLE_PUSH_CREATE_ORG = true;
          };

          # Instance-signed commits Forgejo generates
          "repository.signing" = {
            FORMAT = "ssh";
            SIGNING_KEY = signingKeyPub;
            SIGNING_NAME = "cmu.dev";
            SIGNING_EMAIL = "noreply@cmu.dev";
            INITIAL_COMMIT = "always";
            CRUD_ACTIONS = "always";
            WIKI = "always";
            MERGES = "always";
          };

          mailer = {
            ENABLED = true;
            PROTOCOL = "smtp+starttls";
            SMTP_ADDR = "smtp.mailgun.org";
            SMTP_PORT = 587;
            FROM = "cmu.dev <forgejo@mail.scottylabs.org>";
          };

          service = {
            DISABLE_REGISTRATION = false;
            SHOW_REGISTRATION_BUTTON = true;
            REGISTER_EMAIL_CONFIRM = true;
            ENABLE_NOTIFY_MAIL = true;
          };

          oauth2_client = {
            OPENID_CONNECT_SCOPES = "email profile";
            ENABLE_AUTO_REGISTRATION = true;
            ACCOUNT_LINKING = "auto";
            UPDATE_AVATAR = true;
          };

          openid = {
            ENABLE_OPENID_SIGNIN = false;
          };

          session.COOKIE_SECURE = true;

          # blob storage on Garage over S3
          storage = {
            STORAGE_TYPE = "minio";
            MINIO_ENDPOINT = "s3.scottylabs.org";
            MINIO_USE_SSL = true;
            MINIO_BUCKET = "forgejo";
            MINIO_BUCKET_LOOKUP = "path";
            MINIO_LOCATION = "us-east-1";
          };

          actions.ENABLED = true;
        };
      };

      # Mailgun SMTP username and password
      age.secrets.forgejo-mailer = {
        file = ../../../secrets/infra-01/forgejo-mailer.age;
        mode = "0400";
        owner = "forgejo";
      };

      # Instance signing key private half
      age.secrets.forgejo-signing-key = {
        file = ../../../secrets/infra-01/forgejo-signing-key.age;
        path = signingKeyPriv;
        owner = "forgejo";
        group = "forgejo";
        mode = "0400";
        symlink = false;
      };

      systemd.tmpfiles.rules = [
        "d ${stateDir}/.ssh 0700 forgejo forgejo -"
        "L+ ${signingKeyPub} - - - - ${signingPubKey}"
      ];

      # Keycloak OIDC client_secret from OpenBao
      systemd.services.forgejo = {
        vault.infraSecrets = {
          oidc = {
            path = "forgejo-oidc";
            key = "CLIENT_SECRET";
          };
          storage_access = {
            path = "forgejo-storage";
            key = "MINIO_ACCESS_KEY_ID";
          };
          storage_secret = {
            path = "forgejo-storage";
            key = "MINIO_SECRET_ACCESS_KEY";
          };
        };

        # ssh-keygen for SSH commit signing
        path = [ pkgs.openssh ];
        serviceConfig.EnvironmentFile = config.age.secrets.forgejo-mailer.path;

        # Garage S3 creds from OpenBao
        environment = {
          "FORGEJO__storage__MINIO_ACCESS_KEY_ID__FILE" = "/run/credentials/forgejo.service/storage_access";
          "FORGEJO__storage__MINIO_SECRET_ACCESS_KEY__FILE" =
            "/run/credentials/forgejo.service/storage_secret";
        };

        wants = [
          "keycloak.service"
          "caddy.service"
          "network-online.target"
        ];
        after = [
          "keycloak.service"
          "caddy.service"
          "network-online.target"
        ];

        # Provision the CMU login source once
        preStart = lib.mkAfter ''
          if ! ${lib.getExe config.services.forgejo.package} admin auth list \
            | ${pkgs.gnugrep}/bin/grep -qw CMU; then
            ${lib.getExe config.services.forgejo.package} admin auth add-oauth \
              --name CMU \
              --provider openidConnect \
              --key forgejo \
              --secret "$(cat "$CREDENTIALS_DIRECTORY/oidc")" \
              --auto-discover-url https://idp.scottylabs.org/realms/scottylabs/.well-known/openid-configuration \
              --scopes "openid email profile" \
              --group-claim-name groups \
              --admin-group /projects/devops/admins \
              --allow-username-change \
              --skip-local-2fa
          fi
        '';
      };

      services.caddy.virtualHosts."git.cmu.dev".extraConfig = ''
        reverse_proxy 127.0.0.1:3002
      '';

      scottylabs.postgresql.databases = [ "forgejo" ];
    };

  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.forgejo = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/forgejo.tfstate";

            dns.git = {
              zone = "cmu.dev";
              host = "infra-01";
              type = "CNAME";
              comment = "Forgejo";
            };

            resource.keycloak_openid_client.forgejo = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "forgejo";
              name = "Forgejo";
              enabled = true;
              access_type = "CONFIDENTIAL";
              standard_flow_enabled = true;
              direct_access_grants_enabled = false;
              valid_redirect_uris = [ "https://git.cmu.dev/user/oauth2/CMU/callback" ];
            };

            resource.keycloak_openid_group_membership_protocol_mapper.forgejo_groups = {
              realm_id = "\${data.keycloak_realm.scottylabs.id}";
              client_id = "\${keycloak_openid_client.forgejo.id}";
              name = "groups";
              claim_name = "groups";
              full_path = true;
            };

            resource.vault_kv_secret_v2.forgejo_oidc = {
              mount = "secret";
              name = "infra/forgejo-oidc";
              data_json = "\${jsonencode({ CLIENT_SECRET = keycloak_openid_client.forgejo.client_secret })}";
            };

            resource.garage_bucket.forgejo.global_alias = "forgejo";

            resource.garage_key.forgejo.name = "forgejo";

            resource.garage_bucket_permission.forgejo = {
              access_key_id = "\${garage_key.forgejo.id}";
              bucket_id = "\${garage_bucket.forgejo.id}";
              read = true;
              write = true;
              owner = false;
            };

            resource.vault_kv_secret_v2.forgejo_storage = {
              mount = "secret";
              name = "infra/forgejo-storage";
              data_json = "\${jsonencode({ MINIO_ACCESS_KEY_ID = garage_key.forgejo.id, MINIO_SECRET_ACCESS_KEY = garage_key.forgejo.secret_access_key })}";
            };
          }
        ];
      };
    };
}
