{
  perSystem = _: {
    terranix.terranixConfigurations.keycloak.modules = [
      {
        resource.keycloak_realm.scottylabs = {
          realm = "scottylabs";
          display_name = "ScottyLabs";
          login_theme = "terrier";
          remember_me = true;
          default_signature_algorithm = "RS256";

          sso_session_idle_timeout = "24h";
          sso_session_max_lifespan = "168h";
          offline_session_idle_timeout = "720h";
          offline_session_max_lifespan = "1440h";
          offline_session_max_lifespan_enabled = false;
          access_token_lifespan = "5m";

          smtp_server = {
            host = "smtp.mx.cloudflare.net";
            port = "465";
            ssl = true;
            starttls = false;
            from = "noreply@scottylabs.org";
            from_display_name = "ScottyLabs Accounts";
            auth = {
              username = "api_token";
              # Resolved by Keycloak's file vault from the scottylabs_smtp credential
              password = "$\${vault.smtp}";
            };
          };
        };
      }
    ];
  };
}
