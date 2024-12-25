{
  poetry2nix,
  python310,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = python310;
  };
in
runCommand "click-test" { } ''
  ${env}/bin/python -c 'import click'
  touch $out
''
