{ lib, poetry2nix, python310, runCommand, gnugrep }:
let
  app = poetry2nix.mkPoetryApplication {
    python = python310;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    src = lib.cleanSource ./.;
    pythonImportsCheck = [
      "test_pyside6"
    ];
  };
in
(runCommand "test-pyside6"
  {
    nativeBuildInputs = [ gnugrep ];
  } ''
  set -euo pipefail
  ${app}/bin/test_pyside6 > $out
  grep QPoint < $out
  grep Success < $out
'') // {
  inherit (app.python.pkgs) pyside6-addons pyside6-essentials;
}
