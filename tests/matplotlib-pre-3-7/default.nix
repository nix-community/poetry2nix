{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "matplotlib-pre-3-7-test" { } ''
  ${env}/bin/python -c 'import matplotlib'
  touch $out
''
