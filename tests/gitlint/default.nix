{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "gitlint-test" { } ''
  ${env}/bin/gitlint --version > $out
''
