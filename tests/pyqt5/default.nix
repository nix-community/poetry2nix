{ lib, poetry2nix, python39 }:

poetry2nix.mkPoetryApplication {
  python = python39;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
  dontWrapQtApps = true;
}
