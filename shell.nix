{ pkgs ? import (fetchTarball { url = "channel:nixpkgs-unstable"; }) {
    overlays = [
      (import ./overlay.nix)
    ];
  }
}:

let

in
pkgs.mkShell {
  buildInputs = [
    pkgs.nixpkgs-fmt
    pkgs.poetry
  ];
}
