{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "fiona-source-test" { } ''
  ${env}/bin/python -c 'import fiona; print(fiona.__version__)' > $out
''
