{
  lib,
  buildPythonPackage,
  litellm,
  poetry-core,
}:

# `litellm-proxy-extras` ships the Prisma schema + SQL migrations the
# LiteLLM proxy needs at runtime. Upstream nixpkgs marks it as
# `# FIXME package litellm-proxy-extras` and excludes it from the
# `extra_proxy` extras, so the proxy crashes on startup with
# `No module named 'litellm_proxy_extras'` whenever DATABASE_URL is set.
#
# The subpackage lives at `litellm-proxy-extras/` inside the same
# BerriAI/litellm tarball already vendored by `pkgs.python3Packages.litellm`;
# reuse `litellm.src` so the schema can never drift from the proxy code.
buildPythonPackage {
  pname = "litellm-proxy-extras";
  version = "0.4.56";
  pyproject = true;

  inherit (litellm) src;
  sourceRoot = "${litellm.src.name}/litellm-proxy-extras";

  build-system = [ poetry-core ];

  pythonImportsCheck = [ "litellm_proxy_extras" ];

  doCheck = false;

  meta = {
    description = "Schema and migrations for the LiteLLM proxy";
    homepage = "https://github.com/BerriAI/litellm";
    license = lib.licenses.mit;
  };
}
