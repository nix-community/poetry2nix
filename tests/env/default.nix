{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    poetrylock = ./poetry.lock;
  };
in
runCommand "env-test" {} ''
  ${env}/bin/python -c 'import alembic'
  touch $out
''
