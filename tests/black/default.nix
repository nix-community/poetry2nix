{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "black-test" { } ''
  ${env}/bin/python -c 'import black'
  ${env}/bin/black --version
  touch $out
''
