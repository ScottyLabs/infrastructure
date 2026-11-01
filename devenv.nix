{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Admins decrypt with the SSH key in users.nix
  admins = builtins.attrValues (import ./users.nix);

  # Hosts decrypt with their SSH host key, which sops-nix imports as the age identity in age.pub
  hosts = lib.concatMapAttrs (
    org:
    lib.mapAttrs' (
      name: host:
      lib.nameValuePair "${org}/${name}" (
        host // { recipient = lib.trim (builtins.readFile ./keys/hosts/${org}/${name}/age.pub); }
      )
    )
  ) (import ./hosts.nix);
  linuxHosts = lib.filterAttrs (_: host: !lib.hasSuffix "-darwin" host.system) hosts;
  recipients = set: map (host: host.recipient) (builtins.attrValues set);

  rule = file: keys: {
    path_regex = "(^|/)secrets/${lib.escapeRegex file}$";
    key_groups = [ { age = keys; } ];
  };
in
{
  imports = [ inputs.scottylabs.devenvModules.default ];

  scottylabs = {
    enable = true;
    project.name = "infrastructure";

    kennel.sites.docs.customDomain = "infra.scottylabs.org";

    # CI runs on aarch64-linux, where patchelf aborts on semgrep-core 1.180.0's binary
    security.semgrep.enable = !(pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64);
  };

  packages = [
    inputs.colmena.packages.${pkgs.system}.colmena
    pkgs.age
    pkgs.jq
    pkgs.mdbook
    pkgs.sops
    pkgs.ssh-to-age
  ];

  # sops rewrites these files itself
  treefmt.config.settings.global.excludes = [ "secrets/**" ];

  # secrets/<org>/<host>.yaml is readable by that host, common.yaml by every NixOS host,
  # and nixbuild.yaml by every host, each alongside the admins
  env.SOPS_CONFIG = (pkgs.formats.yaml { }).generate "sops.yaml" {
    creation_rules =
      lib.mapAttrsToList (id: host: rule "${id}.yaml" (admins ++ [ host.recipient ])) hosts
      ++ [
        (rule "common.yaml" (admins ++ recipients linuxHosts))
        (rule "nixbuild.yaml" (admins ++ recipients hosts))
      ];
  };

  scripts.docs.exec = "cd docs && mdbook serve";
}
