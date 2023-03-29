{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "jupyter-ydoc-test" { } ''
  ${env}/bin/python -c 'import jupyter_ydoc'
  touch $out
''
