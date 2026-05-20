{
  lib,
  fetchFromGitHub,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
}:

# prisma-client-py 0.15.0 pins engine 5.17.0 (commit
# 393aa359c9ad4a4bb28630fb5613f9c281cde053) and refuses to run against
# anything else. nixpkgs only ships `prisma-engines_6` / `_7`.
#
# Mirror the upstream `prisma-engines_6` derivation freshly instead of
# `overrideAttrs`ing it. `rustPlatform.buildRustPackage` bakes the parent's
# `pname-version-vendor` derivation name into the cargo vendor hook, so an
# `overrideAttrs` of pname/version/src/cargoHash fails with
# "Cargo.lock is not the same in <parent-vendor>".
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "prisma-engines-5";
  version = "5.17.0";

  src = fetchFromGitHub {
    owner = "prisma";
    repo = "prisma-engines";
    tag = finalAttrs.version;
    hash = "sha256-52nmCBWzcZtuPp5X9wE6QbPqNtpxN5Wsrwzc2RubX18=";
  };

  # Cargo.lock bump for `time` from 0.3.25 → 0.3.36. The 0.3.25 release
  # fails to compile under rustc >= 1.80 with E0282 in
  # `format_description/parse/mod.rs`; the fix landed in time 0.3.27.
  # Applied as `cargoPatches` so the vendor FOD regenerates with the
  # bumped lockfile.
  cargoPatches = [ ./bump-time.patch ];

  cargoHash = "sha256-eMhRMzCIO8wcPn3i7aqwQCI5r+KTp2/j1brcAa6U6uk=";

  env.OPENSSL_NO_VENDOR = 1;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  preBuild = ''
    export OPENSSL_DIR=${lib.getDev openssl}
    export OPENSSL_LIB_DIR=${lib.getLib openssl}/lib

    export SQLITE_MAX_VARIABLE_NUMBER=250000
    export SQLITE_MAX_EXPR_DEPTH=10000

    export GIT_HASH=0000000000000000000000000000000000000000
  '';

  cargoBuildFlags = [
    "-p"
    "query-engine"
    "-p"
    "query-engine-node-api"
    "-p"
    "schema-engine-cli"
    "-p"
    "prisma-fmt"
  ];

  postInstall = ''
    mv $out/lib/libquery_engine${stdenv.hostPlatform.extensions.sharedLibrary} $out/lib/libquery_engine.node
  '';

  doCheck = false;

  meta = {
    description = "Prisma engines pinned to 5.17.0 for prisma-client-py 0.15.0";
    homepage = "https://www.prisma.io/";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    mainProgram = "prisma";
  };
})
