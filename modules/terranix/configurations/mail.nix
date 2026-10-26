{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.mail = {
        terraformWrapper.package = pkgs.opentofu;
        modules = [
          config.flake.modules.terranix.base
          config.flake.modules.terranix.s3-state
          {
            terraform.backend.s3.key = "services/mail.tfstate";
            cloudflare.token = "terranix-mail";

            dns = {
              scottylabs-org-mx = {
                name = "@";
                type = "MX";
                target = "smtp.google.com";
                priority = 1;
                comment = "Google Workspace inbound mail";
              };
              scottylabs-org-spf = {
                name = "@";
                type = "TXT";
                target = ''"v=spf1 include:_spf.google.com ~all"'';
                comment = "Google Workspace SPF";
              };
              scottylabs-org-dkim = {
                name = "google._domainkey";
                type = "TXT";
                target = ''"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoEeaoM8594pgvtdYlW/sao0Vcr+QPjw34LNdN9fiCIb7dNG19ITGxilAtotIf3UNKGPweNkK0fzbCIhq3YNamME/gZk7Si13cpZIrH0U5WVc22L+M+6sYm948IYlvIzwo0mKXhhV8wxuG6eleuYUx2VgVZRQH+G76HOx9NQKjmn+o9iHm7VrvFIn+WaI8H2dg" "8XLySZG/Cl5FFdywX9Xq/evdMUiKAusA5jekJb5kKUBhb4lsHi1irHS1tENZ7O9K9h6xvlOQZSyNGm1tP2oHCCh1WX9lpOQAIbC4OfbmN48Ls3P5bkHkGkZOPMVJOTmrJ3RnHViE3rUooBciFK9WQIDAQAB"'';
                comment = "Google Workspace DKIM";
              };

              scottylabs-dev-mx = {
                zone = "scottylabs.dev";
                name = "@";
                type = "MX";
                target = "smtp.google.com";
                priority = 1;
                comment = "Google Workspace inbound mail";
              };
              scottylabs-dev-spf = {
                zone = "scottylabs.dev";
                name = "@";
                type = "TXT";
                target = ''"v=spf1 include:_spf.google.com ~all"'';
                comment = "Google Workspace SPF";
              };
              scottylabs-dev-dkim = {
                zone = "scottylabs.dev";
                name = "google._domainkey";
                type = "TXT";
                target = ''"v=DKIM1;k=rsa;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArR/9dmGEsI0nXrE8CsC6m5EmuubBL7Zbxh0YHX+/7z6NScAVfqFV6/2AsnBkg//IBju1PCd7+TP02c04M/F6NYxFI4djiGH/I/xWpYWLMLIOzLVljnXBwvP8JCGZ6YtyRmy60yssjZUgto/+PZhyTI2/am0Wv9C9yjniNMqAQmL28i80F+ExIMwEyjPuI9XFG9m" "8GmET9ofQhOXKHOZ/0EM/EoSVwnCCGtRSdK1Qqach014tbSJztaJi/4tm8Sc0DQj+S2BU081aWBIXvQDm9nNB1Zl5CZiiUm1pIXXtcw/wZZFHNwc7okCxzAP/U1WnH8utefnyBsS3LzXlZ9ZOAwIDAQAB"'';
                comment = "Google Workspace DKIM";
              };
            };
          }
        ];
      };
    };
}
