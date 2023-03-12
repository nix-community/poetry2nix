{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "gitlint-core-test" { } ''
  ${env}/bin/gitlint --version > $out
''
