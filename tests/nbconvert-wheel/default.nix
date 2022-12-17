{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "nbconvert-wheel" { } ''
  ${env}/bin/python -c 'import nbconvert as nbc; print(nbc.__version__)' > $out
''
