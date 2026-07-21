{
  flake.modules.nixos.nixos-mautrix-slack =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.mautrix-slack;
      inherit (cfg) dataDir;
      format = pkgs.formats.yaml { };

      registrationFile = "${dataDir}/slack-registration.yaml";
      settingsFile = "${dataDir}/config.yaml";
      settingsFileUnformatted = format.generate "slack-config-unsubstituted.yaml" cfg.settings;
      default_token = "This value is generated when generating the registration";
    in
    {
      options.services.mautrix-slack = {
        enable = lib.mkEnableOption "Mautrix-Slack, a Matrix-Slack puppeting bridge";

        package = lib.mkPackageOption pkgs "mautrix-slack" { };

        settings = lib.mkOption {
          inherit (format) type;
          default = { };
          description = ''
            {file}`config.yaml` as a Nix attribute set.
            See https://docs.mau.fi/configs/mautrix-slack/latest for options.
          '';
        };

        registerToSynapse = lib.mkOption {
          type = lib.types.bool;
          default = config.services.matrix-synapse.enable;
          defaultText = lib.literalExpression "config.services.matrix-synapse.enable";
          description = "Register the bridge appservice with Synapse.";
        };

        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/mautrix-slack";
          defaultText = "/var/lib/mautrix-slack";
          description = "Directory for bridge config and database.";
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Environment file for secrets substituted into config via envsubst.";
        };

        serviceUnit = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "mautrix-slack.service";
        };

        registrationServiceUnit = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "mautrix-slack-registration.service";
        };

        serviceDependencies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            cfg.registrationServiceUnit
          ]
          ++ lib.optional config.services.matrix-synapse.enable config.services.matrix-synapse.serviceUnit
          ++ lib.optional config.services.matrix-conduit.enable "matrix-conduit.service"
          ++ lib.optional config.services.dendrite.enable "dendrite.service";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion =
              (cfg.settings.homeserver.domain or "") != "" && (cfg.settings.homeserver.address or "") != "";
            message = "services.mautrix-slack.settings.homeserver.domain and .address must be set.";
          }
          {
            assertion = cfg.settings.bridge.permissions or { } != { };
            message = "services.mautrix-slack.settings.bridge.permissions must be set.";
          }
        ];

        users.users.mautrix-slack = {
          isSystemUser = true;
          group = "mautrix-slack";
          extraGroups = [ "mautrix-slack-registration" ];
          home = dataDir;
          description = "Mautrix-Slack bridge user";
        };

        users.groups.mautrix-slack = { };
        users.groups.mautrix-slack-registration = {
          members = lib.optional config.services.matrix-synapse.enable "matrix-synapse";
        };

        services.matrix-synapse = lib.mkIf cfg.registerToSynapse {
          settings.app_service_config_files = [ registrationFile ];
        };

        systemd.tmpfiles.rules = [
          "d ${cfg.dataDir} 770 mautrix-slack mautrix-slack -"
        ];

        systemd.services = {
          matrix-synapse = lib.mkIf cfg.registerToSynapse {
            serviceConfig.SupplementaryGroups = [ "mautrix-slack-registration" ];
            wants = [ cfg.registrationServiceUnit ];
            after = [ cfg.registrationServiceUnit ];
          };

          mautrix-slack-registration = {
            description = "Mautrix-Slack registration generation service";
            wantedBy = lib.mkIf cfg.registerToSynapse [ "multi-user.target" ];
            before = lib.mkIf cfg.registerToSynapse [ "matrix-synapse.service" ];

            path = [
              pkgs.yq
              pkgs.envsubst
              cfg.package
            ];

            script = ''
              rm -f '${settingsFile}'
              old_umask=$(umask)
              umask 0177

              envsubst -o '${settingsFile}' -i '${settingsFileUnformatted}'

              as_token=$(yq -r '.appservice.as_token' '${settingsFile}')
              hs_token=$(yq -r '.appservice.hs_token' '${settingsFile}')
              config_has_tokens=$([[ "$as_token" != "${default_token}" && "$as_token" != "null" && "$hs_token" != "${default_token}" && "$hs_token" != "null" ]] && echo "true" || echo "false")

              if [[ -f '${registrationFile}' ]]; then
                registration_exists="true"
              else
                registration_exists="false"
              fi

              if [[ $config_has_tokens == "false" && $registration_exists == "true" ]]; then
                yq -sY '.[0].appservice.as_token = .[1].as_token | .[0].appservice.hs_token = .[1].hs_token | .[0]' \
                  '${settingsFile}' '${registrationFile}' > '${settingsFile}.tmp'
                mv '${settingsFile}.tmp' '${settingsFile}'
              fi

              if [[ $config_has_tokens == "false" && $registration_exists == "false" ]]; then
                new_as_token=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 64)
                new_hs_token=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 64)

                yq -Y ".appservice.as_token = \"$new_as_token\" | .appservice.hs_token = \"$new_hs_token\"" \
                  '${settingsFile}' > '${settingsFile}.tmp'
                mv '${settingsFile}.tmp' '${settingsFile}'

                if [[ $(yq -r '.appservice.as_token' '${settingsFile}') == "${default_token}" ]]; then
                  echo "ERROR: Failed to replace default tokens"
                  exit 1
                fi
              fi

              cp '${settingsFile}' '${settingsFile}.tmp'
              mautrix-slack --generate-registration --config='${settingsFile}.tmp' --registration='${registrationFile}'
              rm '${settingsFile}.tmp'

              yq -sY '.[1].as_token = .[0].appservice.as_token | .[1].hs_token = .[0].appservice.hs_token | .[1]' \
                '${settingsFile}' '${registrationFile}' > '${registrationFile}.tmp'
              mv '${registrationFile}.tmp' '${registrationFile}'

              umask $old_umask
              chown :mautrix-slack-registration '${registrationFile}'
              chmod 640 '${registrationFile}'
            '';

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              UMask = 27;
              User = "mautrix-slack";
              Group = "mautrix-slack";
              SystemCallFilter = [ "@system-service" ];
              ProtectSystem = "strict";
              ProtectHome = true;
              ReadWritePaths = [ dataDir ];
              StateDirectory = "mautrix-slack";
              EnvironmentFile = cfg.environmentFile;
            };

            restartTriggers = [ settingsFileUnformatted ];
          };

          mautrix-slack = {
            description = "Mautrix-Slack, a Matrix-Slack puppeting bridge";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ] ++ cfg.serviceDependencies;
            after = [ "network-online.target" ] ++ cfg.serviceDependencies;

            serviceConfig = {
              Type = "simple";
              User = "mautrix-slack";
              Group = "mautrix-slack";
              PrivateUsers = true;
              Restart = "on-failure";
              RestartSec = 30;
              WorkingDirectory = dataDir;
              ExecStart = "${lib.getExe cfg.package} --config='${settingsFile}'";
              EnvironmentFile = cfg.environmentFile;
              ProtectSystem = "strict";
              ProtectHome = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectControlGroups = true;
              PrivateDevices = true;
              PrivateTmp = true;
              RestrictSUIDSGID = true;
              RestrictRealtime = true;
              LockPersonality = true;
              ProtectKernelLogs = true;
              ProtectHostname = true;
              ProtectClock = true;
              SystemCallArchitectures = "native";
              SystemCallErrorNumber = "EPERM";
              SystemCallFilter = "@system-service";
              ReadWritePaths = [ cfg.dataDir ];
            };

            restartTriggers = [ settingsFileUnformatted ];
          };
        };
      };
    };
}
