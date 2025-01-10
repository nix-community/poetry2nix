{
  runCommand,
  lib,
  poetry2nix,
  python39,
}:
let
  pkg = poetry2nix.mkPoetryApplication {
    python = python39;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    src = lib.cleanSource ./.;
    overrides = poetry2nix.overrides.withDefaults (
      _: super: {
        opencv-python = super.opencv-python.override {
          preferWheel = true;
        };
      }
    );
  };
  p = pkg.python.withPackages (ps: [
    ps.numpy
    ps.opencv-python
  ]);
in
runCommand "test" { } ''
  ${p}/bin/python -c "import cv2"
  touch $out
''
