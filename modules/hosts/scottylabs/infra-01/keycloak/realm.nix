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
