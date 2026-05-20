{
  lib,
  python3Packages,
  litellmProxyExtras,
  prismaWithLitellm,
}:

# Upstream nixpkgs ships `pkgs.litellm` as
# `toPythonApplication(litellm.overridePythonAttrs (... ++ proxy ++ extra_proxy))`.
# Recreate that shape with two substitutions so the proxy actually
# starts against PostgreSQL:
#
#   * Drop the bare `prisma` from `extra_proxy` and add the generated
#     `prismaWithLitellm` instead.
#   * Append `litellmProxyExtras`, which upstream nixpkgs notes as
#     `# FIXME package litellm-proxy-extras` and excludes outright.
#
# Filtering by `pname == "prisma"` is the only reliable hook because
# both packages share that derivation name; otherwise both would end
# up in `site-packages/prisma/` and one would non-deterministically
# shadow the other.
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
