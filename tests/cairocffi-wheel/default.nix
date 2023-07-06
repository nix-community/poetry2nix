{ poetry2nix, python3, pkgs, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
    overrides = poetry2nix.overrides.withDefaults (
      _: super: {
        cairocffi = super.cairocffi.override {
          preferWheel = true;
        };
      }
    );
  };
in
assert env.python.pkgs.cairocffi.src.isWheel; runCommand "cairocffi-wheel" { } ''
  ${env}/bin/python -c 'import cairocffi; print(cairocffi.__version__)' > $out
''
