{
  poetry2nix,
  python3,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "watchfiles-test" { } ''
  ${env}/bin/python -c 'from watchfiles import watch'
  touch $out
''
