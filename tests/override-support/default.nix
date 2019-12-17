{ lib, python3, poetry2nix, runCommand }:

let
  p = poetry2nix.mkPoetryPython {
    python = python3;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.defaultPoetryOverrides // {
      alembic = self: super: drv: drv.overrideAttrs (
        old: {
          TESTING_FOOBAR = 42;
        }
      );
    };
  };
in
runCommand "test" {} ''
  x=${builtins.toString (p.python.pkgs.alembic.TESTING_FOOBAR)}
  [ "$x" = "42" ] || exit 1
  mkdir $out
''
