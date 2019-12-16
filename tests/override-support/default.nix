{ lib, python3, poetry2nix, runCommand }:

let
  python = poetry2nix.mkPoetryPython {
    python = python3;
    poetryLock = ./poetry.lock;
    src = lib.cleanSource ./.;
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
  x=${builtins.toString (python.pkgs.alembic.TESTING_FOOBAR)}
  [ "$x" = "42" ] || exit 1
  mkdir $out
''
