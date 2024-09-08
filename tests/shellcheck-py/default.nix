{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "shellcheck-py-test" { } ''
  ${env}/bin/python -c 'import os; assert os.path.isfile("${env}/bin/shellcheck")'
  touch $out
''
