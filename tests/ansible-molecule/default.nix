{ lib, poetry2nix, python39 }:

(poetry2nix.mkPoetryApplication {
  python = python39;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
}).overridePythonAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
    old.passthru.python.pkgs.setuptools
  ];
})
