{ lib, poetry2nix, python3 }:

(poetry2nix.mkPoetryApplication {
  python = python3;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
}).overridePythonAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
    old.passthru.python.pkgs.setuptools
  ];
})
