{ poetry2nix, pkgsCross }:

let
  pkgs = pkgsCross.aarch64-multiplatform;
in
pkgs.poetry2nix.mkPoetryApplication {
  python = pkgs.python3;
  projectDir = ./.;
}
