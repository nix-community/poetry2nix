{ lib, poetry2nix, python38 }:
let
  inherit (builtins) elem map;
  drv = poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    python = python38;
  };
  packageNames = map (package: package.pname) drv.poetryPackages;
in
assert builtins.elem "certifi" packageNames; drv
