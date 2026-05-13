{
  description = "Grafana dashboards and alert rules for ScottyLabs services";

  outputs = { self, ... }: {
    dashboards = ./dashboards;
    alerts = ./alerts;
  };
}
