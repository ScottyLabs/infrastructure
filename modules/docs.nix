{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.docs = (inputs.kennel.mkLib pkgs).buildMdbook {
        src = ../docs;
        name = "infrastructure-docs";
      };
    };
}
