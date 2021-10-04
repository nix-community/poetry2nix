{ lib, poetry2nix, runCommand }:
poetry2nix.mkPoetryApplication {
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
}
