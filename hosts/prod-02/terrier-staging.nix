{
  terrier,
  ...
}:

{
  imports = [
    terrier.nixosModules.default
  ];

  scottylabs.bao-agent = {
    enable = true;
    secrets.terrier-staging = {
      project = "terrier";
      user = "terrier-staging";
    };
  };

  services.terrier = {
    enable = true;
    user = "terrier-staging";
    group = "terrier-staging";
    environmentFile = "/run/secrets/terrier-staging.env";
    extraGroups = [ "redis-terrier-staging" ];
    dependencies = [
      "postgresql.service"
      "redis-terrier-staging.service"
      "minio-terrier-staging.service"
    ];
  };

  scottylabs.postgresql.databases = [ "terrier-staging" ];
  scottylabs.valkey.servers = [ "terrier-staging" ];
  scottylabs.minio.instances.terrier-staging = {
    port = 9000;
    consolePort = 9001;
    credentialsFile = "/run/secrets/terrier-staging.env";
  };

  # Nginx reverse proxy
  services.nginx = {
    enable = true;

    virtualHosts."terrier-staging.scottylabs.org" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };

    # Extend the minio module's virtualHost with larger upload limit
    virtualHosts."s3.terrier-staging.scottylabs.org".extraConfig = ''
      client_max_body_size 100M;
    '';
  };
}
