{
  poetry2nix,
  python39,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python39;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "pytest_randomly" { } ''
  ${env}/bin/python -c 'import pytest_randomly'
  touch $out
''
