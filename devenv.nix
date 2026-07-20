{ inputs, pkgs, ... }:

{
  imports = [ inputs.scottylabs.devenvModules.default ];

  scottylabs = {
    enable = true;
    project.name = "infrastructure";
  };

  packages = [ inputs.colmena.packages.${pkgs.system}.colmena ];
}
