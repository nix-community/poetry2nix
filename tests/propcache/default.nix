{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python310;
    projectDir = ./.;
  };
in
runCommand "propcache-test" { } ''
  ${env}/bin/python -c 'import propcache; print(propcache.__version__)' > $out
''
