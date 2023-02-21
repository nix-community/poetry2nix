{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "rfc3986-validator-test" { } ''
  ${env}/bin/python -c 'import rfc3986_validator; print(rfc3986_validator.__version__)' > $out
''
