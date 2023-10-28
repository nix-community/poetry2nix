{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "pytest-redis-test" { } ''
  ${env}/bin/python -c 'import pytest_redis'
  touch $out
''
