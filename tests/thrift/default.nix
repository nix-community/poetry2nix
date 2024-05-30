{ poetry2nix, python312, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python312;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "thrift-test" { } ''
  ${env}/bin/python -c 'import thrift'
  touch $out
''
