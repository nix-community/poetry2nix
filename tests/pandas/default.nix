{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "pandas-test" { } ''
  ${env}/bin/python -c 'import pandas'
  touch $out
''
