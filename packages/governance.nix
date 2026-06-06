{
  lib,
  rustPlatform,
  governance,
}:

rustPlatform.buildRustPackage rec {
  pname = "governance";
  version = "0.1.0";
  src = governance;

  cargoLock.lockFile = "${governance}/Cargo.lock";

  cargoBuildFlags = [ "-p governance" ];

  doCheck = false;

  meta = with lib; {
    description = "ScottyLabs governance CLI";
    license = licenses.mit;
  };
}
