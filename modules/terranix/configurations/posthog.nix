{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.posthog = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          {
            terraform.backend.s3.key = "services/posthog.tfstate";
            dns.v = {
              type = "CNAME";
              target = "1e191a7f16b24e2e436f.cf-prod-us-proxy.proxyhog.com";
              comment = "PostHog managed reverse proxy";
            };
          }
        ];
      };
    };
}
