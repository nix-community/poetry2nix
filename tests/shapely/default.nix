{ lib, poetry2nix, python38 }:

poetry2nix.mkPoetryApplication {
  python = python38;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
}
