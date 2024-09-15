{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = python310;
  };
in
runCommand "commitizen-test" { } ''
  ${env}/bin/cz ls | grep -q "cz_gitmoji" || exit 1
  touch $out
''
