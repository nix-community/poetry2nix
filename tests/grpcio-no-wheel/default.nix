{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
    overrides = poetry2nix.overrides.withDefaults (
      self: super: {
        grpcio = super.grpcio.override {
          preferWheel = false;
        };
      }
    );
  };

  isWheelGrpcIO = env.python.pkgs.grpcio.src.isWheel;

in
assert (!isWheelGrpcIO); runCommand "grpcio-no-wheel" { } ''
  ${env}/bin/python -c 'import grpc; print(grpc.__version__)' > $out
''
