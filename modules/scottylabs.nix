{ inputs, ... }:

{
  imports = [ inputs.kennel.flakeModules.default ];

  perSystem =
    { system, ... }:
    {
      scottylabs = {
        project.name = "infrastructure";

        shell.packages = [ inputs.colmena.packages.${system}.colmena ];
      };
    };
}
