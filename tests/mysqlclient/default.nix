{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "mysqlclient-test" { } ''
  ${env}/bin/python -c 'import MySQLdb'
  touch $out
''
