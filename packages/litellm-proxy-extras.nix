{
  lib,
  buildPythonPackage,
  fetchurl,
  python,
}:

# `litellm-proxy-extras` ships the Prisma schema and SQL migrations the
# LiteLLM proxy loads at startup whenever `DATABASE_URL` is set.
#
# Built from the official PyPI wheel; nixpkgs does not yet package this.
buildPythonPackage rec {
  pname = "litellm-proxy-extras";
  version = "0.4.73";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/1d/64/7e85f5f47495ebb0bb5f30a4f4b54b64277a40a14be79c34052df97ac7ab/litellm_proxy_extras-0.4.73-py3-none-any.whl";
    hash = "sha256-pPRg0V3QGgldrbJvdmCiWfoqh1ep4n3uaMFZqHK4234=";
  };

  pythonImportsCheck = [ "litellm_proxy_extras" ];

  doCheck = false;

  meta = {
    description = "Schema and migrations for the LiteLLM proxy";
    homepage = "https://pypi.org/project/litellm-proxy-extras/";
    license = lib.licenses.mit;
  };
}
