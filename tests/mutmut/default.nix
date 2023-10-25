{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = python310;
  };
in
runCommand "mutmut-test" { } ''
  ${env}/bin/mutmut version > $out
''
