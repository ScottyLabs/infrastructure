{
  description = "Grafana dashboards and alert rules for ScottyLabs services";

  outputs = _: {
    dashboards = ./dashboards;
    alerts = ./alerts;
  };
}
