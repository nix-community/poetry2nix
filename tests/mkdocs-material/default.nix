{ poetry2nix, python3 }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
env.python.pkgs.mkdocs-material
