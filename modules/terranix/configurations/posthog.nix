{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.posthog = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          (
            { config, ... }:
            {
              terraform.backend.s3.key = "services/posthog.tfstate";

              terraform.required_providers.posthog = {
                source = "PostHog/posthog";
                version = "~> 1.0";
              };

              variable = {
                posthog_token.sensitive = true;
                posthog_organization_id.type = "string";
              };

              provider.posthog = {
                api_key = "\${var.posthog_token}";
                host = "https://us.posthog.com";
                organization_id = "\${var.posthog_organization_id}";
              };

              resource.posthog_proxy_record.v.domain = "v.${config.dns.v.zone}";

              dns.v = {
                type = "CNAME";
                target = "\${posthog_proxy_record.v.target_cname}";
                comment = "PostHog managed reverse proxy";
              };
            }
          )
        ];
      };
    };
}
