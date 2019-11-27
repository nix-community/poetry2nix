{ pkgs ? import (fetchTarball https://nixos.org/channels/nixpkgs-unstable/nixexprs.tar.xz) {} }:
let 
  poetry = pkgs.callPackage ../pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
  poetry2nix = import ../default.nix { inherit pkgs; inherit poetry; };
in
  poetry2nix.mkPoetryPackage {
    python = pkgs.python3;
    pyproject = ./pyproject.toml;
    poetryLock = ./poetry.lock;
    src = pkgs.lib.cleanSource ./.;
  }
