{ lib, ... }:
let
  sourceType = lib.types.oneOf [
    lib.types.path
    lib.types.str
    (lib.types.attrsOf lib.types.anything)
  ];

  namedItems = lib.mkOption {
    default = [ ];
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          source = lib.mkOption { type = sourceType; };
        };
      }
    );
  };

  ds = {
    type = "prometheus";
    uid = "prometheus";
  };

  grafana = {
    inherit ds;

    target =
      {
        expr,
        legend ? null,
        format ? null,
        instant ? false,
      }:
      {
        inherit expr;
      }
      // lib.optionalAttrs (legend != null) { legendFormat = legend; }
      // lib.optionalAttrs (format != null) { inherit format; }
      // lib.optionalAttrs instant { inherit instant; };

    panel =
      type:
      {
        title,
        pos,
        targets,
        id ? null,
        defaults ? null,
        options ? null,
        transformations ? null,
      }:
      {
        inherit type title targets;
        gridPos = pos;
        datasource = ds;
      }
      // lib.optionalAttrs (defaults != null) { fieldConfig = { inherit defaults; }; }
      // lib.optionalAttrs (options != null) { inherit options; }
      // lib.optionalAttrs (transformations != null) { inherit transformations; }
      // lib.optionalAttrs (id != null) { inherit id; };

    stat = grafana.panel "stat";
    timeseries = grafana.panel "timeseries";
    table = grafana.panel "table";

    grid =
      panels:
      let
        place =
          acc: p:
          let
            w = p.gridPos.w;
            h = p.gridPos.h;
            wrap = acc.x + w > 24;
            x = if wrap then 0 else acc.x;
            y = if wrap then acc.y + acc.rowH else acc.y;
          in
          {
            x = x + w;
            inherit y;
            rowH = if wrap then h else lib.max acc.rowH h;
            out = acc.out ++ [
              (
                p
                // {
                  gridPos = p.gridPos // {
                    inherit x y;
                  };
                }
              )
            ];
          };
      in
      (lib.foldl' place {
        x = 0;
        y = 0;
        rowH = 0;
        out = [ ];
      } panels).out;

    thresholds = steps: {
      mode = "absolute";
      inherit steps;
    };

    dashboard =
      {
        title,
        uid,
        tags ? [ "infra" ],
        refresh ? "30s",
        from ? "now-1h",
        panels,
      }:
      {
        inherit
          title
          uid
          tags
          refresh
          ;
        schemaVersion = 39;
        timezone = "browser";
        time = {
          inherit from;
          to = "now";
        };
        panels = lib.imap1 (i: p: { id = i; } // p) panels;
      };

    promAlert =
      {
        name,
        uid,
        title,
        expr,
        severity,
        summary,
        annotations ? { },
        labels ? { },
        duration ? "1m",
        interval ? "1m",
        folder ? "alerts",
        from ? 300,
        noData ? "Alerting",
        execErr ? "Alerting",
      }:
      {
        apiVersion = 1;
        groups = [
          {
            orgId = 1;
            inherit name folder interval;
            rules = [
              {
                inherit uid title;
                condition = "A";
                "for" = duration;
                noDataState = noData;
                execErrState = execErr;
                annotations = {
                  inherit summary;
                }
                // annotations;
                labels = {
                  inherit severity;
                }
                // labels;
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = {
                      inherit from;
                      to = 0;
                    };
                    datasourceUid = "prometheus";
                    model = {
                      datasource = ds;
                      inherit expr;
                      instant = true;
                      intervalMs = 60000;
                      refId = "A";
                    };
                  }
                ];
              }
            ];
          }
        ];
      };

    thresholdAlert =
      {
        name,
        uid,
        title,
        expr,
        threshold,
        severity,
        summary,
        annotations ? { },
        labels ? { },
        op ? "gt",
        duration ? "5m",
        interval ? "1m",
        folder ? "alerts",
        from ? 600,
        noData ? "Alerting",
        execErr ? "Alerting",
      }:
      {
        apiVersion = 1;
        groups = [
          {
            orgId = 1;
            inherit name folder interval;
            rules = [
              {
                inherit uid title;
                condition = "B";
                "for" = duration;
                noDataState = noData;
                execErrState = execErr;
                annotations = {
                  inherit summary;
                }
                // annotations;
                labels = {
                  inherit severity;
                }
                // labels;
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = {
                      inherit from;
                      to = 0;
                    };
                    datasourceUid = "prometheus";
                    model = {
                      datasource = ds;
                      inherit expr;
                      instant = true;
                      intervalMs = 60000;
                      refId = "A";
                    };
                  }
                  {
                    refId = "B";
                    relativeTimeRange = {
                      inherit from;
                      to = 0;
                    };
                    datasourceUid = "__expr__";
                    model = {
                      type = "threshold";
                      expression = "A";
                      conditions = [
                        {
                          evaluator = {
                            type = op;
                            params = [ threshold ];
                          };
                        }
                      ];
                      refId = "B";
                    };
                  }
                ];
              }
            ];
          }
        ];
      };

    upAlert =
      { job, ... }@args:
      grafana.promAlert (removeAttrs args [ "job" ] // { expr = ''up{job="${job}"} == bool 0''; });
  };
in
{
  options.scottylabs.observability = {
    dashboards = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            folder = lib.mkOption { type = lib.types.str; };
            name = lib.mkOption { type = lib.types.str; };
            source = lib.mkOption { type = sourceType; };
          };
        }
      );
    };

    alerts = {
      rules = namedItems;
      contactPoints = namedItems;
      policies = namedItems;
    };
  };
  config._module.args.grafana = grafana;
}
