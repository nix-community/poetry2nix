{ poetry2nix, python3 }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (_: prev: {
      watchdog = prev.watchdog.override { preferWheel = true; };
    });
  };
in
env.python.pkgs.mkdocs-material
