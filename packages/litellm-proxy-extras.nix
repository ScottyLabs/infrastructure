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
  version = "0.4.56";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/7a/91/b54c96cfd1f0fabeca686bf400cb7d7c3c12f15df4359d42deefd0fc2bb2/litellm_proxy_extras-0.4.56-py3-none-any.whl";
    hash = "sha256-UtvjtTWMeQ534S8exe+OdQizg8Kq9BKZdQtvtACQjuc=";
  };

  pythonImportsCheck = [ "litellm_proxy_extras" ];

  doCheck = false;

  # Upstream `_get_prisma_dir` calls `shutil.copytree(src, dst, dirs_exist_ok=True)`
  # from the package dir under /nix/store. `_copytree` ends with `copystat(src, dst)`,
  # which copies the Nix store's read-only (0555) mode onto the destination tree.
  # The first call within a process succeeds, but locks every dir at 0555; the
  # second call (same process) cannot write into them. Restore owner-writable
  # mode after each copytree so subsequent calls succeed.
  postInstall = ''
    utils=$out/${python.sitePackages}/litellm_proxy_extras/utils.py
    substituteInPlace "$utils" \
      --replace-fail \
        'shutil.copytree(src_path, dst_path, dirs_exist_ok=True)' \
        'shutil.copytree(src_path, dst_path, dirs_exist_ok=True); [os.chmod(r, 0o700) or [os.chmod(os.path.join(r, f), 0o600) for f in fs] for r, _, fs in os.walk(dst_path)]' \
      --replace-fail \
        'shutil.copytree(pkg_migrations_dir, custom_migrations_dir)' \
        'shutil.copytree(pkg_migrations_dir, custom_migrations_dir); [os.chmod(r, 0o700) or [os.chmod(os.path.join(r, f), 0o600) for f in fs] for r, _, fs in os.walk(custom_migrations_dir)]'
  '';

  meta = {
    description = "Schema and migrations for the LiteLLM proxy";
    homepage = "https://pypi.org/project/litellm-proxy-extras/";
    license = lib.licenses.mit;
  };
}
