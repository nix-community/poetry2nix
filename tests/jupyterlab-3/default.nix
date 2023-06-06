{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "jupyterlab-3-test" { } ''
  ${env}/bin/jupyter-lab --version > $out
''
