{ poetry2nix, python3, runCommand }:
let
  env1 = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
  env2 = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "ruff-test"
{ } ''
  ${env1}/bin/ruff version
  ${env2}/bin/ruff version
  touch $out
''
