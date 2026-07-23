{ pkgs, inputs, ... }:

{
  imports = [ inputs.scottylabs.devenvModules.default ];

  scottylabs.enable = true;

  scripts.grafana-dev.exec = ''
    exec ${pkgs.grafana}/bin/grafana server \
      --homepath ${pkgs.grafana}/share/grafana \
      --config "$DEVENV_ROOT/.devenv/grafana.ini"
  '';

  enterShell = ''
    mkdir -p "$DEVENV_ROOT/.devenv/grafana-data"
    cat > "$DEVENV_ROOT/.devenv/grafana.ini" <<EOF
    [paths]
    data         = $DEVENV_ROOT/.devenv/grafana-data
    provisioning = $DEVENV_ROOT/.devenv/provisioning

    [server]
    http_addr = 127.0.0.1
    http_port = 3000

    [auth.anonymous]
    enabled  = true
    org_role = Admin

    [security]
    disable_initial_admin_creation = true

    [dashboards]
    default_home_dashboard_path =
    EOF

    mkdir -p "$DEVENV_ROOT/.devenv/provisioning/dashboards" "$DEVENV_ROOT/.devenv/provisioning/datasources"
    cat > "$DEVENV_ROOT/.devenv/provisioning/dashboards/scottylabs.yaml" <<EOF
    apiVersion: 1
    providers:
      - name: scottylabs
        folder: ""
        type: file
        allowUiUpdates: false
        disableDeletion: true
        options:
          path: $DEVENV_ROOT/dashboards
          foldersFromFilesStructure: true
    EOF
  '';
}
