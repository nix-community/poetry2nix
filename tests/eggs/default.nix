{ lib, poetry2nix, python37, runCommandNoCC }:
let
  drv = poetry2nix.mkPoetryApplication {
    python = python37;
    projectDir = ./.;
  };
in
runCommandNoCC "egg-test"
{ } ''
  ${drv}/bin/egg-test
  touch $out
''
