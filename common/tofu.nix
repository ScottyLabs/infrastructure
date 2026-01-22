{ config, lib, pkgs, ... }:

let
  cfg = config.scottylabs.tofu;
in
{
  options.scottylabs.tofu = {
    configurations = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.path;
            description = "Path to the OpenTofu configuration directory";
          };

          environmentFile = lib.mkOption {
            type = lib.types.path;
            description = ''
              Path to an environment file containing secrets.
              This file should define any TF_VAR_* variables and auth tokens.
            '';
          };

          after = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Systemd services to wait for before applying";
          };

          preCheck = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = ''
              Shell script to run before applying.
              Use this to wait for services to be ready (e.g., unsealed).
              Exit 0 to proceed, exit non-zero to skip.
            '';
          };

          environment = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Additional environment variables for OpenTofu";
          };
        };
      });
      default = {};
      description = ''
        OpenTofu configurations to apply declaratively.

        Each configuration gets its own state directory at /var/lib/tofu-<name>
        and a systemd service that applies the configuration on boot.
        State is backed up before each apply.
      '';
      example = lib.literalExpression ''
        {
          openbao = {
            source = ../../tofu/openbao;
            environmentFile = config.age.secrets.openbao.path;
            after = [ "openbao.service" ];
            environment.VAULT_ADDR = "http://127.0.0.1:8200";
            preCheck = '# Wait for OpenBao to be unsealed';
          };
        }
      '';
    };
  };

  config = lib.mkIf (cfg.configurations != {}) {
    # Create state and backup directories for each configuration
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (name: _: [
      "d /var/lib/tofu-${name} 0700 root root -"
      "d /var/lib/tofu-${name}/backups 0700 root root -"
    ]) cfg.configurations);

    systemd.services = lib.mapAttrs' (name: conf: {
      name = "tofu-${name}";
      value = {
        description = "Apply ${name} configuration via OpenTofu";
        after = [ "network-online.target" ] ++ conf.after;
        wants = [ "network-online.target" ] ++ conf.after;
        wantedBy = [ "multi-user.target" ];

        # Re-run when the source config changes
        restartTriggers = [ conf.source ];

        path = [ pkgs.opentofu pkgs.gzip ];
        environment = conf.environment;

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          EnvironmentFile = conf.environmentFile;
        };

        script = ''
          set -euo pipefail
          STATE_DIR="/var/lib/tofu-${name}"
          BACKUP_DIR="$STATE_DIR/backups"

          # Run pre-check script if provided
          ${lib.optionalString (conf.preCheck != "") ''
            echo "Running pre-check..."
            if ! (${conf.preCheck}); then
              echo "Pre-check failed or requested skip, exiting"
              exit 0
            fi
          ''}

          # Backup existing state before making changes
          if [ -f "$STATE_DIR/terraform.tfstate" ]; then
            TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            echo "Backing up state to $BACKUP_DIR/terraform.tfstate.$TIMESTAMP.gz"
            gzip -c "$STATE_DIR/terraform.tfstate" > "$BACKUP_DIR/terraform.tfstate.$TIMESTAMP.gz"

            # Keep only the 10 most recent backups
            ls -t "$BACKUP_DIR"/terraform.tfstate.*.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
          fi

          # Copy configuration files to state directory
          rm -rf "$STATE_DIR"/*.tf "$STATE_DIR"/*.json
          cp ${conf.source}/*.tf "$STATE_DIR/"
          cp ${conf.source}/*.json "$STATE_DIR/" 2>/dev/null || true
          cd "$STATE_DIR"

          # Initialize and apply
          tofu init -upgrade
          tofu apply -auto-approve
        '';
      };
    }) cfg.configurations;
  };
}
