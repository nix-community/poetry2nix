{ pkgs ? import <nixpkgs> {} }:
let
  poetry = pkgs.callPackage ../pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
  poetry2nix = import ./.. { inherit pkgs; inherit poetry; };
in
{
  trivial = pkgs.callPackage ./trivial { inherit poetry2nix; };
  override = pkgs.callPackage ./override-support { inherit poetry2nix; };
  top-packages-1 = pkgs.callPackage ./common-pkgs-1 { inherit poetry2nix; };
  top-packages-2 = pkgs.callPackage ./common-pkgs-2 { inherit poetry2nix; };
  git-deps = pkgs.callPackage ./git-deps { inherit poetry2nix; };
}
