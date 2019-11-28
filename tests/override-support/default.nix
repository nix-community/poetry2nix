{ lib, python3, poetry2nix, runCommand }:

let 
  pyApp = poetry2nix.mkPoetryPackage {
    python = python3;
    pyproject = ./pyproject.toml;
    poetryLock = ./poetry.lock;
    src = lib.cleanSource ./.;
    overrides = poetry2nix.defaultPoetryOverrides // {
      alembic = self: super: drv: drv.overrideAttrs(old: {
        TESTING_FOOBAR = 42;
      });
    };
  };
in
  runCommand "test" {} ''
    x=${builtins.toString (pyApp.pythonPackages.alembic.TESTING_FOOBAR)}
    [ "$x" = "42" ] || exit 1
    mkdir $out
  ''
