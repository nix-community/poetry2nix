{ lib, poetry2nix, python3, runCommand }:
let
  envWheel = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
    preferWheels = true;
  };
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
  };
in
runCommand "jake-test" { } ''
  ${envWheel}/bin/python -c 'import jake'
  ${env}/bin/python -c 'import jake'
  touch $out
''
