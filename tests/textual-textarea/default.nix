{ poetry2nix, python311, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "textual-textarea-test" { } ''
  ${env}/bin/python -c 'import textual_textarea' > $out
''
