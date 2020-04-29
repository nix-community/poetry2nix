{ lib, poetry2nix, python3, runCommand }:
let
  py = poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    preferWheels = true;
  };
  isWheelAttr = py.python.pkgs.tensorflow.src.isWheel or false;
in
  assert isWheelAttr; (py.python.withPackages (_: py.poetryPackages)).override (args: { ignoreCollisions = true; })
