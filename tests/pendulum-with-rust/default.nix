{ lib, poetry2nix, python39 }:
poetry2nix.mkPoetryApplication {
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
  python = python39;
}
