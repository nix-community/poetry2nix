{ lib, poetry2nix, python311 }:

poetry2nix.mkPoetryApplication {
  python = python311;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
}
