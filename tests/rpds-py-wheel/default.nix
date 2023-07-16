{ poetry2nix, python3, pkgs }:
let
  inherit (pkgs.stdenv) isLinux;
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
    overrides = poetry2nix.overrides.withDefaults (
      _: super: {
        rpds-py = super.rpds-py.override {
          preferWheel = isLinux;
        };
        referencing = super.referencing.override {
          preferWheel = isLinux;
        };
        jsonschema-specifications = super.jsonschema-specifications.override {
          preferWheel = isLinux;
        };
      }
    );
  };
in
assert isLinux ->
env.python.pkgs.rpds-py.src.isWheel
  && env.python.pkgs.referencing.src.isWheel
  && env.python.pkgs.jsonschema-specifications.src.isWheel; env
