{ poetry2nix, python3, pkgs, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
    overrides = poetry2nix.overrides.withDefaults (
      _: super: {
        contourpy = super.contourpy.override {
          preferWheel = true;
        };
        numpy = super.numpy.override {
          preferWheel = true;
        };
      }
    );
  };
in
assert env.python.pkgs.contourpy.src.isWheel; runCommand "contourpy-wheel" { } ''
  ${env}/bin/python -c 'import contourpy; print(contourpy.__version__)' > $out
''
