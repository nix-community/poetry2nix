{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "matplotlib-3-9-test" { } ''
  ${env}/bin/python -c 'import matplotlib'
  touch $out
''
