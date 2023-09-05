{ pkgs }:
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
in
pkgs.writeShellApplication {
  name = "update-poetry";
  runtimeInputs = [
    pythonEnv
    pkgs.poetry
    pkgs.nix
  ];
  text = ''
    ${pythonEnv}/bin/python ${./update.py}
  '';
}
