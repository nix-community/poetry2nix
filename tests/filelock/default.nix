{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python310;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "filelock-test" { } ''
  ${env}/bin/python -c 'import filelock; print(filelock.__version__)' > $out
''
