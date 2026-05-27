{ config, ... }:

{
  age.secrets.tofu-cloudflare = {
    file = ../../secrets/infra-01/tofu-cloudflare.age;
    mode = "0400";
  };

  scottylabs.tofu.configurations.cloudflare = {
    source = ../../tofu/cloudflare;
    environmentFile = config.age.secrets.tofu-cloudflare.path;
    preCheck = ''
      STATE_DIR="/var/lib/tofu-cloudflare"
      [ -f "$STATE_DIR/terraform.tfstate" ] || exit 0
      cd "$STATE_DIR"
      tofu init -input=false >/dev/null 2>&1 || exit 0
      tofu state rm 'cloudflare_dns_record.a["matrix-reconciler"]' 2>/dev/null || true
    '';
  };
}
