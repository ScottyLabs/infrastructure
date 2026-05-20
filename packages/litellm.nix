{
  lib,
  python3Packages,
  litellmProxyExtras,
  prismaWithLitellm,
}:

# `pkgs.litellm` packaged with the dependencies required to run the proxy
# against PostgreSQL: the full `proxy` and `extra_proxy` extras with
# `prisma` swapped for `prismaWithLitellm` (the pre-generated client), and
# `litellmProxyExtras` appended for schema + migrations.
#
# Filtering `extra_proxy` by `pname == "prisma"` is required because both
# the upstream `prisma` and `prismaWithLitellm` derivations share that
# pname and would otherwise collide in `site-packages/prisma/`.

let
  base = python3Packages.litellm;

  filteredExtraProxy = builtins.filter (p: (p.pname or "") != "prisma") base.optional-dependencies.extra_proxy;
in
python3Packages.toPythonApplication (
  base.overridePythonAttrs (old: {
    dependencies =
      (old.dependencies or [ ])
      ++ base.optional-dependencies.proxy
      ++ filteredExtraProxy
      ++ [
        litellmProxyExtras
        prismaWithLitellm
      ];

    pythonImportsCheck = (old.pythonImportsCheck or [ ]) ++ [
      "litellm_proxy_extras"
    ];
  })
)
