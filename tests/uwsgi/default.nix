{ lib, poetry2nix }:
poetry2nix.mkPoetryApplication {
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
}
