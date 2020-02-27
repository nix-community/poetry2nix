{ pkgs ? import (fetchTarball { url = "channel:nixpkgs-unstable"; }) {
    overlays = [
      (import ./overlay.nix)
    ];
  }
}:

let
  tools = pkgs.callPackage ./tools {};

in
pkgs.mkShell {
  buildInputs = [
    tools.flamegraph
    pkgs.nixpkgs-fmt
    pkgs.poetry
  ];
}
