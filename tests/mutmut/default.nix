{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "mutmut-test" { } ''
  ${env}/bin/mutmut version > $out
''
