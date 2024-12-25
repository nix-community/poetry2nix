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
runCommand "pyzmq-test" { } ''
  ${env}/bin/python -c 'import zmq; print(zmq.__version__)' > $out
''
