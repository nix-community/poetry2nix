{
  poetry2nix,
  python3,
  pkgs,
}:
let
  inherit (pkgs.stdenv) isLinux;
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
    overrides = poetry2nix.overrides.withDefaults (
      _: prev: {
        rpds-py = prev.rpds-py.override {
          preferWheel = isLinux;
        };

        referencing = prev.referencing.override {
          preferWheel = isLinux;
        };

        jsonschema-specifications = prev.jsonschema-specifications.override {
          preferWheel = isLinux;
        };

        jsonschema = prev.jsonschema.override {
          preferWheel = isLinux;
        };
      }
    );
  };
in
assert
  isLinux
  ->
    env.python.pkgs.rpds-py.src.isWheel
    && env.python.pkgs.referencing.src.isWheel
    && env.python.pkgs.jsonschema-specifications.src.isWheel
    && env.python.pkgs.jsonschema.src.isWheel;
env
