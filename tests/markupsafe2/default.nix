{ lib, poetry2nix, python3 }:

poetry2nix.mkPoetryEnv {
  python = python3;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
}
