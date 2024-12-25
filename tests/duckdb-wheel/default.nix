{
  poetry2nix,
  python39,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python39;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "duckdb-wheel-test" { } ''
  ${env}/bin/python -c 'import duckdb; print(duckdb.__version__)' > $out
''
