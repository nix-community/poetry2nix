{ poetry2nix, python311, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "fastapi-utils-test"
{ } ''
  ${env}/bin/python -c 'import fastapi_utils'
  touch $out
''
