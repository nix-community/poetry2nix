{ lib, poetry2nix, python3, pkgs, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (
      self: super: {
        bokeh = super.bokeh.override {
          preferWheel = true;
        };

        panel = super.panel.override {
          preferWheel = true;
        };

        pillow = super.pillow.override {
          preferWheel = true;
        };
      }
    );
  };
  areWheels = map
    (name: env.python.pkgs.${name}.src.isWheel)
    [ "bokeh" "panel" "pillow" ];
in
assert builtins.all lib.id areWheels; runCommand "panel-wheel" { } ''
  ${env}/bin/python -c 'import panel; print(panel.__version__)' > $out
''
