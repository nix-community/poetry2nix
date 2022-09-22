{ lib, poetry2nix, python3, runCommand }:

let

  app = poetry2nix.mkPoetryApplication {
    projectDir = ./.;
  };

  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };

in
runCommand "trivial-1_2_0-aggregate" { } ''
  echo ${app}
  ${env}/bin/python -c 'import requests'
  touch $out
''
