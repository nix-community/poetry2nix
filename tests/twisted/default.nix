{
  poetry2nix,
  python311,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "twisted-test" { } ''
  ${env}/bin/python -c 'from twisted.web import server, resource'
  touch $out
''
