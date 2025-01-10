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
runCommand "mpi4py-test" { } ''
  ${env}/bin/python -c 'import mpi4py; print(mpi4py.__version__)' > $out
''
