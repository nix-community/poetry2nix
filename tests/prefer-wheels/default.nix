{ lib, poetry2nix, python37, runCommand }:
let
  py = poetry2nix.mkPoetryPackages {
    python = python37;
    projectDir = ./.;
    preferWheels = true;
  };
  isWheelAttr = py.python.pkgs.tensorflow.src.isWheel or false;
in
assert isWheelAttr; runCommand "prefer-wheels" { } "touch $out"
