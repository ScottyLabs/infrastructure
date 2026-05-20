{
  buildNpmPackage,
  lib,
}:

# Offline `PRISMA_BINARY_CACHE_DIR` for `prisma-client-py` 0.15.0.
#
# `prisma.cli.prisma.ensure_cached()` looks for
# `<cache>/node_modules/prisma/build/index.js` and a top-level
# `package.json`; this derivation provides both.
#
# `--ignore-scripts` skips the `prisma` and `@prisma/engines` postinstall
# hooks, which would otherwise reach out to S3 for engine binaries.
# Engines are supplied separately through `prisma-engines-5` and the
# `PRISMA_*_BINARY` environment variables.
buildNpmPackage (finalAttrs: {
  pname = "prisma-cli-cache-5";
  version = "5.17.0";

  src = ./.;

  npmDepsHash = "sha256-/T7YoejLs+ZM4BFtTvmA31HCsLnqf0c+jymOYIssEOQ=";

  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp package.json package-lock.json $out/
    cp -r node_modules $out/
    runHook postInstall
  '';

  meta = {
    description = "Pre-populated prisma@5.17.0 CLI cache for prisma-client-py";
    homepage = "https://github.com/prisma/prisma";
    license = lib.licenses.asl20;
  };
})
