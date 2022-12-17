{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "duckdb-wheel-test" { } ''
  ${env}/bin/python -c 'import duckdb; print(duckdb.__version__)' > $out
''
