{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
assert env.python.pkgs.pyodbc.src.isWheel; runCommand "pyodbc-wheel-test" { } ''
  ${env}/bin/python -c 'import pyodbc'
  touch $out
''
