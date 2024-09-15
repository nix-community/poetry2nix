{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = python310;
  };
in
runCommand "decli-pre-0_6_2-test" { } ''
  ${env}/bin/python -c 'import decli'
  touch $out
''
