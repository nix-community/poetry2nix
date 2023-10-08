{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "arrow-test" { } ''
  ${env}/bin/python -c 'import arrow; print(arrow.__version__)' > $out
''
