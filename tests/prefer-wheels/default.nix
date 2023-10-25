{ poetry2nix, python3, runCommand }:
let
  py = poetry2nix.mkPoetryPackages {
    python = python3;
    projectDir = ./.;
    preferWheels = true;
  };
  isWheelAttr = py.python.pkgs.maturin.src.isWheel or false;
in
assert isWheelAttr; runCommand "prefer-wheels" { } "touch $out"
