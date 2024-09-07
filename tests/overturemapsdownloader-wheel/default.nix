{ poetry2nix, python311, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "overturemapsdownloader-test" { } ''
  ${env}/bin/python -c 'import overturemapsdownloader'
  touch $out
''
