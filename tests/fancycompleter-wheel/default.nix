{ poetry2nix, python3 }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  pkg = env.python.pkgs.fancycompleter;
  isFancycompleterWheel = pkg.src.isWheel;
in
assert isFancycompleterWheel;
pkg
