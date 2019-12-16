let
  pkgs = import (fetchTarball { url = "channel:nixpkgs-unstable"; }) {};
  poetry2nix = import ./. { inherit pkgs; inherit poetry; };
  poetry = pkgs.callPackage ./pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
in
pkgs.mkShell {
  buildInputs = [
    poetry
    pkgs.nixpkgs-fmt
  ];
}
