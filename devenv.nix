{ inputs, pkgs, ... }:

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
    pkgs.mdbook
  ];

  scripts.docs.exec = "cd docs && mdbook serve";
}
