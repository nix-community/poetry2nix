{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "fiona-test" { } ''
  ${env}/bin/python -c 'import fiona; print(fiona.__version__)' > $out
''
