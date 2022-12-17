{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "grpcio-wheel" { } ''
  ${env}/bin/python -c 'import grpc; print(grpc.__version__)' > $out
''
