let
  # assumes nixpkgs and poetry2nix are pinned through niv tool
  # $ nix-shell -p niv
  # $ niv init
  # $ niv add nix-community/poetry2nix
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  poetry2nix = pkgs.callPackage sources.poetry2nix { };
  myPythonApp = poetry2nix.mkPoetryApplication { projectDir = ./.; };
in
myPythonApp
