{ ... }:

{
  imports = [
    ../../platforms/campus-cloud
    ./terrier-staging.nix
  ];

  system.stateVersion = "25.11";
}
