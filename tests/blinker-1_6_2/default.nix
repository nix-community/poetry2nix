{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "blinker-test" { } ''
  ${env}/bin/python -c 'import blinker'
  touch $out
''
