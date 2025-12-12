{ config, pkgs, ... }:

let
  rememberMe = pkgs.fetchurl {
    url = "https://github.com/Herdo/keycloak-remember-me-authenticator/releases/download/v1.0.0/keycloak-remember-me-authenticator-1.0.0.jar";
    sha256 = "sha256-C2SwwFZ9Z8BqczJx8Dx/jnvj8nApncOkyejQz0m+6eA=";
  };
  discord = pkgs.fetchurl {
    url = "https://github.com/wadahiro/keycloak-discord/releases/download/v0.6.1/keycloak-discord-0.6.1.jar";
    sha256 = "sha256-rz+YKV8oiYy+iuwrW0F01gOKuRt0w7FOkxMhFCbzNvs=";
  };

  theme = pkgs.fetchFromGitHub {
    owner = "ScottyLabs";
    repo = "keycloak";
    rev = "a961ae70f06b11d94b56f4a7d43c4d1bbd10c6b9";
    sha256 = "";
  };
in
{
  age.secrets.keycloak = {
    file = ../../secrets/infra-01/keycloak.age;
    mode = "0400";
    owner = "keycloak";
    group = "keycloak";
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "keycloak" ];
    ensureUsers = [{
      name = "keycloak";
      ensureDBOwnership = true;
    }];
  };

  services.keycloak = {
    enable = true;
    database = {
      type = "postgresql";
      host = "localhost";
      name = "keycloak";
      username = "keycloak";
      passwordFile = config.age.secrets.keycloak.path;
    };
    settings = {
      hostname = "idp.scottylabs.org";
      hostname-strict = true;
      proxy-headers = "xforwarded";
      http-enabled = true;
      http-host = "127.0.0.1";
      http-port = 8080;
      log-level = "org.keycloak.broker:debug";
    };
    themes = {
      terrier = pkgs.runCommand "keycloak-terrier-theme" {} ''
        cp -r ${theme}/themes/terrier $out
      '';
    };
    plugins = [ rememberMe discord ];
  };

  services.nginx.virtualHosts."idp.scottylabs.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
      '';
    };
  };
}
