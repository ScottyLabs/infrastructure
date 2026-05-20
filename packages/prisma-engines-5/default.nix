{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gzip,
  openssl,
  zlib,
}:

# Prisma engine binaries for the commit
# `393aa359c9ad4a4bb28630fb5613f9c281cde053` (the 5.17.0 release), fetched
# from `binaries.prisma.sh` and patchelf'd for NixOS.
#
# `prisma-client-py` 0.15.0 hardcodes this commit hash and rejects any
# other engine version.

let
  commit = "393aa359c9ad4a4bb28630fb5613f9c281cde053";
  platform = "debian-openssl-3.0.x";
  base = "https://binaries.prisma.sh/all_commits/${commit}/${platform}";

  fetchEngine =
    name: hash:
    fetchurl {
      url = "${base}/${name}.gz";
      inherit hash;
    };

  queryEngine = fetchEngine "query-engine" "sha256-m8hX3r4NV2DFce5icQdiI9lL6YHCmiJAHeaB8/cOBn0=";
  schemaEngine = fetchEngine "schema-engine" "sha256-mK1DP9ZNouoettVlVTqaQzns8w8cIRsotpaQ9ZEmmkE=";
  prismaFmt = fetchEngine "prisma-fmt" "sha256-5r8j2x5/5FauFn9HRKcd+tkHVyfObQ9lWCpb7l/oeT8=";
  libqueryEngine = fetchEngine "libquery_engine.so.node" "sha256-El11c5vX/NuOq7VCg1W1vgD1QAQ+a8H1swJolHr6sb0=";
in
stdenv.mkDerivation {
  pname = "prisma-engines-5";
  version = "5.17.0";

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    gzip
  ];

  buildInputs = [
    openssl
    zlib
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib

    gunzip -c ${queryEngine}     > $out/bin/query-engine
    gunzip -c ${schemaEngine}    > $out/bin/schema-engine
    gunzip -c ${prismaFmt}       > $out/bin/prisma-fmt
    gunzip -c ${libqueryEngine}  > $out/lib/libquery_engine.node

    chmod +x $out/bin/*

    runHook postInstall
  '';

  meta = {
    description = "Prisma engines pinned to commit 393aa359 (5.17.0) for prisma-client-py 0.15.0";
    homepage = "https://www.prisma.io/";
    license = lib.licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "query-engine";
  };
}
