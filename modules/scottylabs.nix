{ inputs, ... }:

{
  imports = [ inputs.kennel.flakeModules.default ];

  perSystem =
    {
      pkgs,
      helpers,
      system,
      ...
    }:
    {
      scottylabs = {
        project.name = "infrastructure";

        shell = {
          packages = [
            inputs.colmena.packages.${system}.colmena
            pkgs.mdbook
          ];

          scripts.docs = ''cd "$SCOTTYLABS_ROOT/docs" && exec mdbook serve'';
        };
      };

      sites.docs = {
        package = helpers.buildMdbook {
          src = ../docs;
          name = "infrastructure-docs";
        };
        customDomain = "infra.scottylabs.org";
      };
    };
}
