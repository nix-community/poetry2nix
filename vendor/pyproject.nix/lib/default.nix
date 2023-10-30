{ lib }:
let
  inherit (builtins) mapAttrs;
  inherit (lib) fix;
in

fix (self: mapAttrs (_: path: import path ({ inherit lib; } // self)) {
  pip = ./pip.nix;
  pypa = ./pypa.nix;
  project = ./project.nix;
  renderers = ./renderers.nix;
  validators = ./validators.nix;
  poetry = ./poetry.nix;

  pep440 = ./pep440.nix;
  pep508 = ./pep508.nix;
  pep518 = ./pep518.nix;
  pep599 = ./pep599.nix;
  pep600 = ./pep600.nix;
  pep621 = ./pep621.nix;
  pep656 = ./pep656.nix;
})
