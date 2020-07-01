{ lib, poetry2nix, python37, runCommandNoCC }:
let
  drv = poetry2nix.mkPoetryApplication {
    python = python37;
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
