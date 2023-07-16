{ poetry2nix, python3, pkgs }:
let
  inherit (pkgs.stdenv) isLinux;
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
  };
in
assert !(env.python.pkgs.rpds-py.src.isWheel ||
  env.python.pkgs.referencing.src.isWheel ||
  env.python.pkgs.jsonschema-specifications.src.isWheel ||
  env.python.pkgs.jsonschema.src.isWheel
); env
