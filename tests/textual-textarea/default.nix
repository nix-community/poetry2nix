{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "textual-textarea-test" { } ''
  ${env}/bin/python -c 'import textual_textarea' > $out
''
