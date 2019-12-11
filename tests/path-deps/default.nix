{ lib, poetry2nix, python3 }:

poetry2nix.mkPoetryPackage {
  python = python3;
  pyproject = ./pyproject.toml;
  poetryLock = ./poetry.lock;
  src = lib.cleanSource ./.;
  pwd = ./.;
}
