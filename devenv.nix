{ inputs, pkgs, ... }:

{
  imports = [ inputs.scottylabs.devenvModules.default ];

  scottylabs = {
    enable = true;
    project.name = "infrastructure";

    kennel.sites.docs.customDomain = "infra.scottylabs.org";
  };

  packages = [
    inputs.colmena.packages.${pkgs.system}.colmena
    pkgs.mdbook
  ];

  scripts.docs.exec = "cd docs && mdbook serve";
}
