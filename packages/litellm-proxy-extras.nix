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

  # Upstream's post-migration sanity check tries to `mkdir` a baseline-diff
  # directory under the migrations folder. When migrations live in the read-only
  # Nix store the mkdir raises `OSError: Read-only file system`, but the existing
  # handler only matches `Permission denied`. Extend the check so the sanity
  # step degrades to a warning, matching upstream's intent for read-only roots.
  postInstall = ''
    substituteInPlace $out/${python.sitePackages}/litellm_proxy_extras/utils.py \
      --replace-fail \
        'if "Permission denied" in str(e):' \
        'if "Permission denied" in str(e) or "Read-only file system" in str(e):'
  '';

  meta = {
    description = "Schema and migrations for the LiteLLM proxy";
    homepage = "https://pypi.org/project/litellm-proxy-extras/";
    license = lib.licenses.mit;
  };
}
