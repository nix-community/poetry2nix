{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "pyproj-test" { } ''
  ${env}/bin/python -c 'import pyproj'
  touch $out
''
