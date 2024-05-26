{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "color-operations-test" { } ''
  ${env}/bin/python -c 'import color_operations; print(color_operations.__version__)' > $out
''
