{
  description = "Grafana dashboards and alert rules for ScottyLabs services";

  outputs = {
    dashboards = ./dashboards;
    alerts = ./alerts;
  };
}
