{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "pydantic-1-test" { } ''
  ${env}/bin/python -c 'import pydantic.main; pydantic.main.Field(default=0, ge=0)'
  touch $out
''
