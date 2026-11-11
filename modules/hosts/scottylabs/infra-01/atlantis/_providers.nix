{ pkgs, forgejoProvider }:
let
  inherit (pkgs) lib;
  p = pkgs.opentofu.plugins;
  target = "${pkgs.go.GOOS}_${pkgs.go.GOARCH}";

  plugin = host: provider: {
    name = "${host}/${lib.removePrefix "registry.terraform.io/" provider.provider-source-address}/${provider.version}/${target}";
    path = "${provider}/libexec/terraform-providers/${provider.provider-source-address}/${provider.version}/${target}";
  };
  opentofu = map (plugin "registry.opentofu.org");
  terraform = map (plugin "registry.terraform.io");

  github =
    args:
    p.mkProvider (
      {
        homepage = "https://registry.terraform.io/providers/${lib.toLower args.owner}/${lib.removePrefix "terraform-provider-" args.repo}";
      }
      // args
    );

  forgejo = {
    name = "registry.opentofu.org/svalabs/forgejo/1.7.0/${target}";
    path = forgejoProvider;
  };

  cloudflare = p.cloudflare_cloudflare.override {
    rev = "v5.28.1";
    hash = "sha256-u/jcdMNh/+Jm/jJ7YBZronwUvNRLoZUJZdzS1kF/2O0=";
    vendorHash = "sha256-IakHMXfSiIazr2sPSugOc/+2JQ7wh2rUcY0hYJYf6Eg=";
    mkProviderGoModule = pkgs.buildGoLatestModule;
  };
  vault = p.hashicorp_vault.override {
    rev = "v5.13.0";
    hash = "sha256-kfIulbpyQrUCpCYvUTupqfxRVFl6n+wAJyyq5U4NhFg=";
    vendorHash = "sha256-1S21quLvX103K1mq4i0FhKH+cC4vwdJ/oI+embmQHSs=";
    mkProviderGoModule = pkgs.buildGoLatestModule;
  };
  posthog = github {
    owner = "PostHog";
    repo = "terraform-provider-posthog";
    rev = "v1.0.28";
    spdx = "MPL-2.0";
    hash = "sha256-PCKehRIAfxJbfnSlJLfXUkTMrcoNOIATBlaPGmo8AaI=";
    vendorHash = null;
    mkProviderGoModule = pkgs.buildGoLatestModule;
  };
in
{
  terranix = pkgs.linkFarm "terranix-tofu-plugins" (
    opentofu [
      cloudflare
      p.keycloak_keycloak
      vault
      p.hashicorp_random
      p.hashicorp_tls
      (p.hashicorp_google.override {
        rev = "v7.46.2";
        hash = "sha256-5wEsjWzIe+vFBSv4La3aVPhxlMv3oDSylzXMNbq3ivQ=";
        vendorHash = "sha256-Q4vjlWbm0BSZdlLJbLadGfjqjhimhjC0nJYd57VNEOU=";
        proxyVendor = true;
        mkProviderGoModule = pkgs.buildGoLatestModule;
      })
      posthog
    ]
    ++ terraform [ p.jkossis_garage ]
    ++ [ forgejo ]
  );

  governance = pkgs.linkFarm "governance-tofu-plugins" (
    opentofu [
      cloudflare
      p.keycloak_keycloak
      vault
      p.hashicorp_random
      p.hashicorp_null
      p.integrations_github
      posthog
      (p.hashicorp_google.override {
        rev = "v5.45.2";
        hash = "sha256-4mrNhC1LYrXPzxgAkmI2SRA5lLSWnOQjUiaLMnhYX1Q=";
        vendorHash = "sha256-ehSNjkz1F0gZnm/5LOEJ72vhBV/bkkka4kXlgIMTpNA=";
      })
      (p.jianyuan_sentry.override {
        rev = "v0.14.13";
        hash = "sha256-5PXljI0uRjmpJXwJZsoEod/GCgxCA4ti94ubflyaNJY=";
        vendorHash = "sha256-RAVDPsbCnZ/3TSpq5lZb9Ega0AigNLxyG5wsLWPkoaU=";
      })
      (github {
        owner = "ap-1";
        repo = "terraform-provider-grouper";
        rev = "v0.1.0";
        spdx = "Apache-2.0";
        hash = "sha256-8BlBTLA2lTX5Abifm+pxjXiH9QLLM7uvYYxYtQ+/kzA=";
        vendorHash = "sha256-7cXh0VmLAhzc/Hz4/ZTcOmjJJz5J7nBGexVgXCgu4Oo=";
      })
      (github {
        owner = "Lucky3028";
        repo = "terraform-provider-discord";
        # TODO: v2.7.0 doesn't build with go 1.27
        rev = "3710abd02c98b70f1e5cd991261e7a145aa051a6";
        version = "2.7.0";
        spdx = "GPL-3.0-only";
        hash = "sha256-OzakkZVmMNJJTa00V5NWQ2F6FYnfFCQuXk0C+9jnci4=";
        vendorHash = "sha256-CeAREcDIkB58fD+otSgpjhkHCVU1TuPNldmVdO9hRSY=";
      })
      (github {
        owner = "Mastercard";
        repo = "terraform-provider-restapi";
        rev = "v1.20.0";
        spdx = "Apache-2.0";
        hash = "sha256-uFPNgnMZIeqc6bYHiuOotjAdkQz81Hib3QiCXtSkCOc=";
        vendorHash = "sha256-WqG5T24oCUn03S+Yhrypb3Xu1BYxTGHxNJacXkbCndU=";
      })
      (p.mkProvider {
        owner = "thesuperRL";
        repo = "terraform-provider-synapse";
        rev = "c73b79f99a3306e499ec8574d760013e1e05365f";
        version = "0.2.0";
        spdx = "MIT";
        hash = "sha256-NRI7nGXDapLSlMpNdRIoISQRbxe7NCE7LMxu7ODGHzI=";
        vendorHash = "sha256-9ulA228kGBXeEnUvuLyFf+9Xd8ewmvGUfMp9YpF6tFY=";
        mkProviderFetcher = args: pkgs.fetchFromGitea (args // { domain = "codeberg.org"; });
        provider-source-address = "registry.terraform.io/thesuperrl/synapse";
      })
    ]
    ++ terraform [
      p.jkossis_garage
      (github {
        owner = "AhmedOsman00";
        repo = "terraform-provider-apple";
        rev = "v0.7.0";
        spdx = "MPL-2.0";
        hash = "sha256-4gSKpQ8Xc3X8zCQFZvwPqb9BgyolMrDHqp7HaEMpcB0=";
        vendorHash = "sha256-hUxB7OF/3EfK9KlHPT1ox2TOkLOUqHO0W49yC3WPkzU=";
      })
      (github {
        owner = "ncecere";
        repo = "terraform-provider-litellm";
        rev = "v2.2.3";
        spdx = "Apache-2.0";
        hash = "sha256-awTUuxbMwMLCJggaMP4QkUqH3QFdppju4qnd/5sq3qg=";
        vendorHash = "sha256-2YDwzQ5zUTck/eEgLTj2iKPpk2mDScxuEKrjjL8Cua0=";
      })
      (github {
        owner = "Oliver-Binns";
        repo = "terraform-provider-googleplay";
        rev = "0.7.2";
        spdx = "MIT";
        hash = "sha256-wK7+mASrL9UlMOgbu0TKMEAQQsUia+rX+4LvzNanRKQ=";
        vendorHash = "sha256-uBr3gjuUdLJNVYR3b4fKVcO0R/HJQZMSWQnRawJpk88=";
      })
    ]
    ++ [ forgejo ]
  );
}
