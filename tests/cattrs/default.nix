{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "cattrs-test" { } ''
  ${env}/bin/python -c 'import cattrs'
  touch $out
''
