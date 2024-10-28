{ poetry2nix, python311 }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
env.python.pkgs.mkdocs-material
