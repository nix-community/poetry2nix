{ lib, poetry2nix, python3, pkgs, runCommand }:
let
  wheelImports = {
    bokeh = "bokeh";
    panel = "panel";
    pillow = "PIL";
  };
  wheelPackages = builtins.attrNames wheelImports;
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
  areWheels = map (name: env.python.pkgs.${name}.src.isWheel) wheelPackages;
  mkImportCall = pkg: "${env}/bin/python -c 'import ${pkg}; print(${pkg}.__version__)' > $out/${pkg}";
in
assert builtins.all lib.id areWheels; runCommand "panel-wheels" { } ''
  mkdir -p "$out"
  ${lib.concatStringsSep "\n" (map (pkg: mkImportCall wheelImports.${pkg}) wheelPackages)}
''
