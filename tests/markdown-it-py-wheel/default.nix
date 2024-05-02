{ poetry2nix, python3, pkgs }:
let
  inherit (pkgs.stdenv) isLinux;
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
    overrides = poetry2nix.overrides.withDefaults (
      _final: prev: {
        markdown-it-py = prev.markdown-it-py.override {
          preferWheel = isLinux;
        };
      }
    );
  };
in
assert isLinux -> env.python.pkgs.markdown-it-py.src.isWheel; env
