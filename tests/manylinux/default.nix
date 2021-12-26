{ runCommand, lib, poetry2nix, python38 }:
let
  pkg = poetry2nix.mkPoetryApplication {
    python = python38;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    src = lib.cleanSource ./.;
  };
  p = pkg.python.withPackages (ps: [ ps.numpy ps.opencv-python ]);
in
runCommand "test"
{ } ''
  ${p}/bin/python -c "import cv2"
  touch $out
''
