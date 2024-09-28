{ lib, poetry2nix, python311, pkgs, runCommand }:
let
  wheelImports = {
    bokeh = "bokeh";
    panel = "panel";
    pillow = "PIL";
  };
  wheelPackages = builtins.attrNames wheelImports;
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (
      _final: prev: {
        bokeh = prev.bokeh.override {
          preferWheel = true;
        };

        panel = prev.panel.override {
          preferWheel = true;
        };

        pillow = prev.pillow.override {
          preferWheel = true;
        };
      }
    );
  };
  areWheels = map (name: env.python.pkgs.${name}.src.isWheel) wheelPackages;
  mkImportCall = pkg: "${env}/bin/python -c 'import ${pkg}; print(${pkg}.__version__)' > $out/${pkg}";
in
assert builtins.all lib.id areWheels; runCommand "panel-wheels" { } ''
  mkdir -p "$out"
  ${lib.concatStringsSep "\n" (map (pkg: mkImportCall wheelImports.${pkg}) wheelPackages)}
''
