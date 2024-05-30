{ poetry2nix, python311, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    # necessary otherwise we can't use older versions of pyarrow
    # and flink requires pyarrow<12
    preferWheels = true;
  };
in
runCommand "flink-test" { } ''
  ${env}/bin/python -c 'import pyflink'
  touch $out
''
