{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = python310;
  };
in
runCommand "click-pre-8_1_8-test" { } ''
  ${env}/bin/python -c 'import click'
  touch $out
''
