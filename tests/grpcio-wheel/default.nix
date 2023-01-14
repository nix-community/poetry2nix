{ lib, poetry2nix, python3, pkgs, runCommand }:
let
  inherit (pkgs.stdenv) isLinux;
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
    overrides = poetry2nix.overrides.withDefaults (
      self: super: {
        grpcio = super.grpcio.override {
          preferWheel = isLinux;
        };
      }
    );
  };
in
assert isLinux -> env.python.pkgs.grpcio.src.isWheel; env
