{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "black-test" { } ''
  ${env}/bin/black --check --code="" --verbose
  touch $out
''
