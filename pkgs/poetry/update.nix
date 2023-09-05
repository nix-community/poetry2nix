let
  pkgs = import <nixpkgs> {
    overlays = [
      (import ../../overlay.nix)
    ];
  };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.requests
  ]);

in
pkgs.mkShell {
  packages = [
    pythonEnv
    pkgs.poetry
    pkgs.nix
  ];
}
