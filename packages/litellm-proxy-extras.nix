{
  lib,
  buildPythonPackage,
  fetchurl,
}:

# `litellm-proxy-extras` ships the Prisma schema and SQL migrations the
# LiteLLM proxy loads at startup whenever `DATABASE_URL` is set.
#
# Built from the official PyPI wheel; nixpkgs does not yet package this.
buildPythonPackage rec {
  pname = "litellm-proxy-extras";
  version = "0.4.56";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/7a/91/b54c96cfd1f0fabeca686bf400cb7d7c3c12f15df4359d42deefd0fc2bb2/litellm_proxy_extras-0.4.56-py3-none-any.whl";
    hash = "sha256-UtvjtTWMeQ534S8exe+OdQizg8Kq9BKZdQtvtACQjuc=";
  };

  pythonImportsCheck = [ "litellm_proxy_extras" ];

  doCheck = false;

  meta = {
    description = "Schema and migrations for the LiteLLM proxy";
    homepage = "https://pypi.org/project/litellm-proxy-extras/";
    license = lib.licenses.mit;
  };
}
