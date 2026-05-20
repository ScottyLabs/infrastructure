{
  buildNpmPackage,
  lib,
}:

# Pre-populated PRISMA_BINARY_CACHE_DIR layout consumed by
# prisma-client-py 0.15.0's `prisma.cli.prisma.ensure_cached()`, which
# expects `<cache>/node_modules/prisma/build/index.js` to exist and a
# top-level `package.json`. We ship those offline so the Python CLI
# never reaches for npm at runtime.
#
# `--ignore-scripts` is required: prisma@5.17.0's preinstall and
# @prisma/engines' postinstall both download platform-specific engine
# binaries over HTTPS. We supply those separately via prisma-engines-5
# and the PRISMA_*_BINARY env vars.
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
