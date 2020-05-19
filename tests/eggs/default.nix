{ lib, poetry2nix, python3, runCommandNoCC }:
let
  drv = poetry2nix.mkPoetryApplication {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    src = lib.cleanSource ./.;
  };
in
runCommandNoCC "egg-test"
{ } ''
  ${drv}/bin/egg-test
  touch $out
''
