{
  lib,
  buildPythonPackage,
  fetchPypi,
}:

# `litellm-proxy-extras` ships the Prisma schema and SQL migrations the
# LiteLLM proxy loads at startup whenever `DATABASE_URL` is set.
#
# Built from the official PyPI wheel; nixpkgs does not yet package this.
buildPythonPackage rec {
  pname = "litellm-proxy-extras";
  version = "0.4.56";
  format = "wheel";

  src = fetchPypi {
    pname = "litellm_proxy_extras";
    inherit version format;
    python = "py3";
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
