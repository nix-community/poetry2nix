{ poetry2nix, python3, stdenv }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (_: prev: {
      watchdog = prev.watchdog.override {
        preferWheel = stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64;
      };
    });
  };
in
env.python.pkgs.mkdocs-material
