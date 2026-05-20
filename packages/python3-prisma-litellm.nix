{
  lib,
  prisma,
  python,
  nodejs,
  # Passed in explicitly by the caller:
  prismaEngines5,
  prismaCliCache5,
  litellmProxyExtras,
}:

# prisma-client-py 0.15.0 raises at runtime unless a project-specific
# Prisma client has been generated against a schema. We bake that
# generation into the derivation by running `python -m prisma generate`
# against litellm's schema during postFixup, writing the rendered
# templates (`client.py`, `models.py`, ...) into this derivation's own
# `site-packages/prisma/` so consumers get a ready-to-import package.
prisma.overridePythonAttrs (old: {
  pname = "prisma-with-litellm-schema";

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ nodejs ];

  postFixup = (old.postFixup or "") + ''
    echo "[prisma-with-litellm-schema] generating Prisma client for litellm schema"

    # Engine binaries are picked up by both the JS prisma CLI (during
    # schema parsing) and the Python client (at runtime).
    export PRISMA_QUERY_ENGINE_BINARY="${prismaEngines5}/bin/query-engine"
    export PRISMA_QUERY_ENGINE_LIBRARY="${lib.getLib prismaEngines5}/lib/libquery_engine.node"
    export PRISMA_SCHEMA_ENGINE_BINARY="${prismaEngines5}/bin/schema-engine"
    export PRISMA_FMT_BINARY="${prismaEngines5}/bin/prisma-fmt"

    # `ensure_cached()` looks for $PRISMA_BINARY_CACHE_DIR/node_modules/prisma/build/index.js;
    # when present, it skips the `npm install prisma@<ver>` it would otherwise run.
    export PRISMA_BINARY_CACHE_DIR="${prismaCliCache5}"
    export PRISMA_HIDE_UPDATE_MESSAGE=true
    export PRISMA_USE_GLOBAL_NODE=true

    export HOME=$TMPDIR

    sitedir="$out/${python.sitePackages}"
    export PYTHONPATH="$sitedir''${PYTHONPATH:+:$PYTHONPATH}"
    export PATH="$out/bin:$PATH"

    workdir=$(mktemp -d)
    cp ${litellmProxyExtras}/${python.sitePackages}/litellm_proxy_extras/schema.prisma "$workdir/schema.prisma"

    (cd "$workdir" && ${python.interpreter} -m prisma generate --schema=schema.prisma)

    if [ ! -f "$sitedir/prisma/models.py" ] || [ ! -f "$sitedir/prisma/client.py" ]; then
      echo "ERROR: Prisma client generation produced no output"
      ls -la "$sitedir/prisma/"
      exit 1
    fi
  '';

  pythonImportsCheck = (old.pythonImportsCheck or [ ]) ++ [
    "prisma.models"
    "prisma.client"
  ];

  passthru = (old.passthru or { }) // {
    schemaSource = litellmProxyExtras;
    engines = prismaEngines5;
  };
})
